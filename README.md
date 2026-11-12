# Reimbursaurus

```
                 __
                / _)        .---------------.
       _.----._/ /          | $ $ $ $ $ $ $ |
      /         /   ,--.----|  REIMBURSED   |
   __/ (  | (  |   /   '----| $ $ $ $ $ $ $ |
  /__.-'|_|--|_|--'         '---------------'
                            Rawr. Your receipts, paid back.
```

**A Claude Code skill that turns receipt PDFs into Step Up For Students reimbursement requests.**

[![Buy Me a Coffee](https://img.shields.io/badge/Buy%20Me%20a%20Coffee-support-FFDD00?logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/moasr)

A [Claude Code](https://claude.com/claude-code) skill that turns a folder of receipt PDFs into reimbursement requests on the Step Up For Students scholarship portal (`apply.stepupforstudents.org`). It works for one child or several, across Step Up programs: FES-UA (Unique Abilities), FES-EO, FTC, and PEP.

> **Unofficial.** This project has no link to Step Up For Students. Eligibility is decided by Step Up, not by this skill. You sign the attestation on every submission, so you are responsible for what you submit.

## What it does

1. Reads each receipt PDF: order number, date, items, prices, tax, vendor.
2. Opens the portal in your own Chrome through [Claude in Chrome](https://claude.com/claude-in-chrome), one draft per receipt.
3. Picks the student, uploads the receipt, and fills every required field, including category, type, description, tax per item, vendor, and a short learning note.
4. Checks that the portal total matches the receipt total.
5. Submits only after you say yes, then moves the PDF to `Receipt_processed/`.
6. Refreshes its list of reimbursable items from Step Up's current purchasing guides on request, one per program.

## Safety rules built in

- It never types your password. You sign in. If your session times out, it stops and asks.
- It never clicks the final Submit without a clear yes from you in chat.
- It picks the best category and does not judge eligibility. Step Up decides.
- It deletes drafts only after you approve.

## Install

Requires Claude Code, the Claude in Chrome extension, and `pdftotext` (`brew install poppler` on macOS).

```bash
git clone https://github.com/rafioso24/reimbursaurus.git
cp -r reimbursaurus/skills/submitting-stepup-reimbursements ~/.claude/skills/
```

## Use

Put receipt PDFs in a folder, open Claude Code there, and say:

> Submit my Step Up reimbursements from the receipts in this folder.

For several children, use one subfolder per child (`Alex/`, `Sam/`), or tell Claude which receipt belongs to whom.

## Keep the item list fresh

Step Up updates its purchasing guides often, and the rules differ by program. Ask Claude to "refresh the reimbursable items list", or run:

```bash
bash ~/.claude/skills/submitting-stepup-reimbursements/scripts/refresh-guide.sh          # all programs
bash ~/.claude/skills/submitting-stepup-reimbursements/scripts/refresh-guide.sh FES-UA   # one program (FES-UA, FTC-FES-EO, PEP)
```

The script downloads each current guide, saves its text under `reference/`, and shows what changed since the last run. It does not ship copies of the guides, because they belong to Step Up. When a new school year starts, update the guide URLs at the top of the script.

## Files

| Path | Purpose |
|---|---|
| `skills/submitting-stepup-reimbursements/SKILL.md` | The skill: flow, field rules, safety rules |
| `skills/submitting-stepup-reimbursements/category-map.md` | Portal categories, an item-to-category table, and differences between programs |
| `skills/submitting-stepup-reimbursements/scripts/refresh-guide.sh` | Fetches the current purchasing guides and diffs them |

## Support the project

If this saved you an evening, you can buy me a coffee.

- Buy Me a Coffee: https://buymeacoffee.com/moasr
- Venmo: [@moasr](https://venmo.com/u/moasr)

## License

MIT. See `LICENSE`.
