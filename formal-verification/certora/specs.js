// https://docs.certora.com/en/latest/docs/confluence/perplexed.html
// https://docs.certora.com/en/latest/docs/cvl/cvl2/changes.html?highlight=prover_args#prover-args
// https://docs.certora.com/en/latest/docs/cvl/cvl2/changes.html?highlight=smt_useBV#changes-for-bitwise-operations

// 'send_only' is deprecated and is now the default. In CI, use 'wait_for_results false' instead
const defaultOptions = [
  // "--debug",
  // "--loop_iter 4",
  // "--optimistic_loop",
  // "--global_timeout 600",
  "--smt_timeout 900",
  // "--rule_sanity basic",
  "--send_only",
];

const certoraFolder = "./formal-verification/certora";

// useBV with summaries doesn't play well
// suggestions from https://docs.certora.com/en/latest/docs/confluence/perplexed.html
// issues with | -mediumTimeout 20 -divideByConstants true -cegar true
// https://docs.certora.com/en/latest/docs/prover/cli/options.html?highlight=prover_args
// https://www.youtube.com/watch?v=mntP0_EN-ZQ
// https://docs.certora.com/en/latest/docs/user-guide/timeouts.html
const proverArgsPresets = [
  "--prover_args '-deleteSMTFile false -canonicalizeTAC false -s [z3,cvc5:nonlin,cvc4]'",
  "--prover_args '-deleteSMTFile false -canonicalizeTAC false -smt_hashingScheme PlainInjectivity -s [yices,z3,cvc5:nonlin,cvc4]'",
  // -canonicalizeTAC false helps with variables names being preserved in the dump
  // mitigation 1 | moderate size (2^25 paths) + nonlinear arithmetic
  "--prover_args '-deleteSMTFile false -smt_hashingScheme PlainInjectivity -s [yices,z3] -canonicalizeTAC false'",
  // mitigation 2 | medium-large graph (2^80 paths) + lightweight arithmetic
  "--prover_args '-deleteSMTFile false -smt_hashingScheme PlainInjectivity -s [yices,z3] -splitParallel true -depth 15 -dontStopAtFirstSplitTimeout true -numOfParallelSplits 5 -splitParallelInitialDepth 8 -canonicalizeTAC false'",
  // mitigation 3 | high path count (2^221) => change code
];

const specs = [
  {
    spec: "FeeFlowController",
    msg: "Test Fee flow controller buying auction",
    contract: "FeeFlowControllerHarness",
    files: [`${certoraFolder}/harnesses/FeeFlowControllerHarness.sol`],
    options: [proverArgsPresets[0], ...defaultOptions],
  },
];

module.exports = {
  specs,
  certoraFolder,
};
