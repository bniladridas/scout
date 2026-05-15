# Scout GitHub App

Workflows can use a GitHub App identity so PR labels and releases show the Scout app avatar instead of the default Actions bot.
Issue labels use the same Scout app identity.
Inactive issue and PR cleanup uses the same Scout app identity.
PR readiness comments use the same Scout app identity.

Create a GitHub App with these repository permissions:

- Checks: read and write
- Contents: read and write
- Issues: read and write
- Pull requests: read and write

Install the app on this repository, then add these repository secrets:

```text
SCOUT_APP_ID
SCOUT_APP_PRIVATE_KEY
```

The private key value should be the full PEM text from the GitHub App settings.
