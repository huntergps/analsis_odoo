# GitHub Sync Instructions

## Repository Information
- Local Path: `/opt/odoo/libs/odoo-tools`
- GitHub Repository: https://github.com/huntergps/analsis_odoo
- Branch: main

## Current Status
✅ Git repository initialized
✅ All files committed locally
✅ Remote origin configured
❌ Push to GitHub (requires authentication)

## To Complete the Push to GitHub

### Option 1: Using Personal Access Token (Recommended)

1. Create a GitHub Personal Access Token:
   - Go to GitHub Settings → Developer Settings → Personal Access Tokens → Tokens (classic)
   - Generate new token with `repo` scope
   - Copy the token

2. Push using the token:
   ```bash
   cd /opt/odoo/libs/odoo-tools
   git push https://<YOUR_GITHUB_USERNAME>:<YOUR_TOKEN>@github.com/huntergps/analsis_odoo.git main
   ```

### Option 2: Using SSH Key

1. Generate SSH key on the server (if not already exists):
   ```bash
   ssh-keygen -t ed25519 -C "hunter@galapagos.tech"
   cat ~/.ssh/id_ed25519.pub
   ```

2. Add the public key to GitHub:
   - Go to GitHub Settings → SSH and GPG keys → New SSH key
   - Paste the public key

3. Change remote to SSH:
   ```bash
   cd /opt/odoo/libs/odoo-tools
   git remote set-url origin git@github.com:huntergps/analsis_odoo.git
   git push -u origin main
   ```

### Option 3: Clone from Local to Another Machine

If you have GitHub access from another machine:

1. On another machine with GitHub access:
   ```bash
   git clone https://github.com/huntergps/analsis_odoo.git
   ```

2. Copy files from server:
   ```bash
   scp -r root@csolish.galapagos.tech:/opt/odoo/libs/odoo-tools/* analsis_odoo/
   cd analsis_odoo
   git add .
   git commit -m "Initial commit from server"
   git push origin main
   ```

## Verify Repository Contents

The repository includes:
- ✅ odoo_config_parser.sh - Configuration file parser library
- ✅ vacuum_selective.sh - VACUUM FULL for largest tables
- ✅ vacuum_full_database.sh - Complete database VACUUM FULL
- ✅ analisis_odoo.sh - Comprehensive analysis report
- ✅ README.md - Main documentation
- ✅ README_VACUUM.md - VACUUM guide
- ✅ README_REUTILIZABLE.md - Reusability guide
- ✅ LICENSE - MIT License
- ✅ .gitignore - Git ignore rules

## After Successful Push

Once pushed, you can clone the repository on any Odoo server:

```bash
cd /opt/odoo/libs
git clone https://github.com/huntergps/analsis_odoo.git odoo-tools
cd odoo-tools
chmod +x *.sh

# Run analysis
./analisis_odoo.sh

# With specific Odoo directory
./analisis_odoo.sh -d /opt/odoo

# With specific config file
./analisis_odoo.sh -c /opt/odoo/conf/odoo.conf
```

## Keep Repository Updated

To update the repository with future changes:

```bash
cd /opt/odoo/libs/odoo-tools
git add .
git commit -m "Description of changes"
git push origin main
```

## Pull Updates on Other Servers

```bash
cd /opt/odoo/libs/odoo-tools
git pull origin main
```
