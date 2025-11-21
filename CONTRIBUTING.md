# Contributing to RWA Tokenization Protocol

Thank you for your interest in contributing to the RWA Tokenization Protocol! We welcome contributions from the community to help make real-world asset tokenization more accessible and secure.

## 🛠️ Getting Started

1.  **Fork the repository** to your own GitHub account.
2.  **Clone the project** to your local machine:
    ```bash
    git clone https://github.com/your-username/frontend-rwa.git
    cd frontend-rwa
    ```
3.  **Install dependencies**:
    ```bash
    forge install
    npm install
    ```
4.  **Create a new branch** for your feature or bug fix:
    ```bash
    git checkout -b feat/amazing-feature
    ```

## 🧪 Running Tests

We use [Foundry](https://book.getfoundry.sh/) for testing. Please ensure all tests pass before submitting a PR.

```bash
# Run all tests
forge test

# Run tests with verbosity (for debugging)
forge test -vvvv

# Run a specific test
forge test --match-test test_MyFeature
```

## 📝 Coding Standards

-   **Solidity Version**: We use Solidity `^0.8.20`.
-   **Style**: Follow the official [Solidity Style Guide](https://docs.soliditylang.org/en/v0.8.20/style-guide.html).
-   **Comments**: Use NatSpec format for all public interfaces (contracts, functions, events).
-   **Safety**: Always use `SafeERC20` for token transfers.

## 🚀 Submission Guidelines

1.  **Commit Messages**: Use [Conventional Commits](https://www.conventionalcommits.org/) format.
    -   `feat: add new staking mechanism`
    -   `fix: resolve reentrancy vulnerability`
    -   `docs: update README`
2.  **Pull Requests**:
    -   Provide a clear description of the changes.
    -   Link to any relevant issues.
    -   Ensure CI checks pass.

## 🐛 Reporting Bugs

If you find a bug, please open an issue on GitHub with:
-   A clear title.
-   Steps to reproduce.
-   Expected vs. actual behavior.

Thank you for helping us build the future of RWA!
