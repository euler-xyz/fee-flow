# Fee Flow

Efficient, decentralised and MEV resistant mechanism to convcert fee assets to a single token. Powered by a continous auto adjusting Dutch auction mechanism.

For more information, refer to the [whitepaper](docs/whitepaper.md)

## How to run

```bash
# compile
forge build
# test
forge test
# generate coverage
forge coverage --report lcov && genhtml lcov.info --branch-coverage --output-dir coverage
```

## Security

Fee Flow has been audited by Zellic, Ottersec and Team Omega. You can find the audit reports [here](audits/)

**No warranties are provided** and **no liability will be accepted for any loss** incurred through the use of this codebase.


## License

Licensed under the [GPL-2.0-or-later](LICENSE) license.