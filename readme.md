## Arcade Accounts: Long lasting Session Keys for smooth UX

> **Disclaimer:** This feature remains in its experimental phase and hasn't undergone auditing. Its use is entirely at your own discretion and risk. As it stands, Arcade Account is a work-in-progress. Your feedback is valuable to us in its continued development!

> Currently, the Arcade Account is a derivative of the Open Zeppelin Account contract. However, the original repository's lack of Scarb support necessitated a direct integration of its content here. This is a stopgap measure, and future updates will offer a more refined solution.

### What is an Arcade Account

An Arcade Account is an enhanced version of the standard Starknet Account, furnished with several distinctive features:

- It requires an associated master account, established at the time of contract deployment.
- Only the master account can withdraw funds, barring scenarios where explicit permissions have been given to the Arcade Account.
- The use of Eth/Tokens by the Arcade Account is limited to transaction signing, precluding direct transfers to other accounts.

Arcade Accounts were created to mitigate the user experience hurdles that onchain games face when interacting with standard browser-based wallets. These accounts supplement rather than replace traditional wallets, fostering a harmonious coexistence.

### The Rationale Behind an Arcade Account

The interactive nature of onchain games demands a user experience that's fluid and user-friendly. Unfortunately, the current framework of browser-based wallets falls short in providing this, as it compels users to authenticate every transaction, even the routine and repetitive ones. This becomes a substantial inconvenience, disrupting the game flow by forcing users to continually toggle between their wallets and the game.

You might be familiar with the term 'session key.' This is a temporary key used to sign transactions in a web application. Arcade Accounts operate on a similar principle, but with an advantage - they offer longer-lived keys, courtesy of their robust permissioning system. Given the highly restrictive permissions, the key can afford to have an infinite lifespan - a feature that significantly streamlines the user experience and simplifies the system architecture.

### Security Aspects 

Given that Arcade Accounts are designed to operate within the browser, their security is inherently less robust than that of conventional browser extension wallets. 

Nonetheless, these accounts are solely for signing transactions within a game, limiting an attacker's gains in the event of an exploit. The attacker would end up with an essentially useless, valueless account, devoid of the capability to withdraw or transfer funds. Upon detecting the exploit, the master account can immediately revoke the Arcade Account's permissions, recover any remaining funds, and set up a fresh account. This demonstrates the incredible resilience and adaptability that native Account Abstraction provides!


### Cost of deployment

Starknet utilizes a strategy of predeclaring a contract prior to deployment to curb state bloat on the chain. The declaration, which constitutes the major cost, is incurred only once. Following this, the cost of deploying a contract becomes relatively negligible.

This enables the potential for frequent deployment of Arcade Accounts by users directly from web applications, all at minimal cost!


