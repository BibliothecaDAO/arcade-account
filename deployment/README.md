# Arcade Account Deployment

## Overview
To deploy an Arcade Account, you'll need to follow these steps:

1. Create a file named `env` in this directory and add the environment variables as shown in the `env.example` file.

2. Run `sh ./scripts/declare.sh` from this directory to declare the contract and add the declared class hash to the `env` file if it has changed.

3. Go to the `src/constructor.cairo` file in this directory to add the constructor args you would like to use when deploying the contract. 

4. Run `sh ./scripts/deploy.sh` from this directory to deploy the account.