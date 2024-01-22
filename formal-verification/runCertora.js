#!/usr/bin/env node
/* eslint-disable no-console */

// USAGE:
//    node certora/run.js [[CONTRACT_NAME:]SPEC_NAME]* [--all] [--options OPTIONS...] [--specs PATH]
// EXAMPLES:
//    node certora/run.js --all
//    node certora/run.js AccessControl
//    node certora/run.js AccessControlHarness:AccessControl

const proc = require("child_process");
const { PassThrough } = require("stream");
const events = require("events");
const { specs, certoraFolder } = require("./certora/specs.js");

// do a certoraRun --version and make sure its above version > 4.x.x
// if not, print a warning
const version = proc.execSync("certoraRun --version").toString("utf8");
const versionMatch = version.match(/(\d+)\.(\d+)\.(\d+)/);
if (versionMatch) {
  const [, major, minor, patch] = versionMatch;
  if (major < 4) {
    console.error(
      `Warning: Certora version ${major}.${minor}.${patch} is too old. Please update to version 4.0.0 or higher.`
    );
  }
} else {
  console.error(
    `Warning: Could not parse certora version from '${version}'. Please update to version 4.0.0 or higher.`
  );
}

const argv = require("yargs")
  .env("")
  .options({
    all: {
      alias: "a",
      type: "boolean",
    },
    parallel: {
      alias: "p",
      type: "number",
      default: 4,
    },
    options: {
      alias: "o",
      type: "array",
      default: [],
    },
  }).argv;

function match(entry, request) {
  const [reqSpec, reqContract] = request.split(":").reverse();
  return (
    entry.spec == reqSpec && (!reqContract || entry.contract == reqContract)
  );
}

const specsFiltered = specs.filter(
  (s) => argv.all || argv._.some((r) => match(s, r))
);
const limit = require("p-limit")(argv.parallel);

if (argv._.length == 0 && !argv.all) {
  console.error(
    `Warning: No specs requested. Did you forgot to toggle '--all'?`
  );
}

for (const r of argv._) {
  if (!specsFiltered.some((s) => match(s, r))) {
    console.error(`Error: Requested spec '${r}' not found in ${specsFiltered}`);
    process.exitCode = 1;
  }
}

if (process.exitCode) {
  process.exit(process.exitCode);
}

for (const { spec, contract, files, msg, options = [] } of specsFiltered) {
  limit(runCertora, spec, contract, files, msg, [
    ...options.flatMap((opt) => opt.split(" ")),
    ...argv.options,
  ]);
}

// Run certora, aggregate the output and print it at the end
async function runCertora(spec, contract, files, msg, options = []) {
  const args = [
    ...files,
    "--verify",
    `${contract}:${certoraFolder}/specs/${spec}.spec`,
    msg ? `--msg "${msg}"` : undefined,
    ...options,
  ].filter((x) => x);
  console.log(`+ certoraRun ${args.join(" ")}`);
  const child = proc.exec(`certoraRun ${args.join(" ")}`);

  const stream = new PassThrough();
  const output = collect(stream);

  child.stdout.pipe(stream, { end: false });
  child.stderr.pipe(stream, { end: false });

  // as soon as we have a job id, print the output link
  stream.on("data", function logStatusUrl(data) {
    const { "-DjobId": jobId, "-DuserId": userId } = Object.fromEntries(
      data
        .toString("utf8")
        .match(/-D\S+=\S+/g)
        ?.map((s) => s.split("=")) || []
    );

    if (jobId && userId) {
      console.error(
        `[${spec}] https://prover.certora.com/output/${userId}/${jobId}/`
      );
      stream.off("data", logStatusUrl);
    }
  });

  // wait for process end
  const [code, signal] = await events.once(child, "exit");

  // error
  if (code || signal) {
    console.error(`[${spec}] Exited with code ${code || signal}`);
    process.exitCode = 1;
  }

  // get all output
  stream.end();

  // write results in markdown format
  writeEntry(
    spec,
    contract,
    code || signal,
    (await output).match(/https:\/\/prover.certora.com\/output\/\S*/)?.[0]
  );

  // write all details
  console.error(`+ certoraRun ${args.join(" ")}\n` + (await output));
}

// Collects stream data into a string
async function collect(stream) {
  const buffers = [];
  for await (const data of stream) {
    const buf = Buffer.isBuffer(data) ? data : Buffer.from(data);
    buffers.push(buf);
  }
  return Buffer.concat(buffers).toString("utf8");
}

function writeEntry(spec, contract, success, url) {
  //print divider
  console.log();
  console.log("=".repeat(80));
  console.log(`Spec: ${spec}`);
  console.log(`Contract: ${contract}`);
  console.log(`Success: ${success ? "???" : ":heavy_check_mark:"}`);
  console.log(
    `Status: ${url ? `${url?.replace("/output/", "/jobStatus/")}` : "error"}`
  );
  console.log(
    `Debug: ${
      url
        ? `${url?.replace(
            `?anonymousKey=`,
            `/FinalResults.html?anonymousKey=`
          )}`
        : "error"
    }`
  );
  console.log("=".repeat(80));
  console.log();
}
