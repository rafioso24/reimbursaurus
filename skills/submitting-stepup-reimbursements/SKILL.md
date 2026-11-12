---
name: submitting-stepup-reimbursements
description: Use when the user wants to submit reimbursements for school materials, books, or receipts on the Step Up For Students EMA portal (apply.stepupforstudents.org), or has receipt PDFs in a folder to turn into reimbursement requests. Covers FES-UA, FES-EO, FTC, and PEP students.
---

# Submitting Step Up Reimbursements

## Overview
Each receipt becomes one reimbursement in the EMA portal. Use Claude in Chrome. Run one browser tab per receipt, in parallel. Stop before the final submit and get a clear yes from the user.

## Requirements
Nothing to install beyond Claude Code and the Claude in Chrome extension. Check the extension before anything else, even before reading receipts:
1. No `mcp__claude-in-chrome__*` tools and no `enable__mcp__claude-in-chrome` tool: stop. Tell the user to install the extension from https://claude.com/chrome, sign in to it with the same Claude account as Claude Code, then restart Claude Code (or run `/chrome`) and ask again.
2. Only `enable__mcp__claude-in-chrome` exists: call it to turn the tools on.
3. Tools load but `tabs_context_mcp` or `list_connected_browsers` shows no browser: ask the user to open Chrome, check the extension is signed in, and run `/chrome` in Claude Code to connect. Wait for them, then retry once.
Do not try to submit by other means (curl, other browsers) if the extension is missing.
- Paths: `scripts/` and `category-map.md` are in this skill's base directory. Saved guides live in `~/.reimbursaurus/reference/`.
- PDFs: read receipts and guides with the Read tool. Do not pass the `pages` parameter. It needs poppler, which most users lack. Reading the whole file works.

## Setup
1. Load the Chrome tools in one ToolSearch call. Invoke the `claude-in-chrome` skill first.
2. If several browsers are connected, ask the user which one. The right profile is the one signed in to the portal. If the user picks "confirmation screen", call `switch_browser`.
3. Open https://apply.stepupforstudents.org/authentication/login. The user types the password. Never enter it.
4. Read each receipt PDF in the folder. Record order number, date, each item title, each item price, tax, vendor.

## Programs
Step Up runs several scholarship programs. The student dropdown shows each child as `Name : PROGRAM`. Read the program suffix for every child and treat each draft by that child's program.
| Portal program | Guide key (`scripts/refresh-guide.sh`) | Notes |
|---|---|---|
| FES-UA (Unique Abilities) | `FES-UA` | Widest list: digital devices, peripherals, assistive technology, specialized services |
| FES-EO, FTC | `FTC-FES-EO` | Private School Purchasing Guide. No digital devices or most peripherals |
| FTC-PEP, PEP | `PEP` | PEP Purchasing Guide. No digital devices or peripherals. Theme parks limited to one $299 reimbursement per year |
| NWSA (New Worlds) | none | The portal blocks reimbursements. Tell the user to use Marketplace or Direct Pay |
- The portal's reimbursement flow is the same for every program. Only eligibility differs.
- Before the first submission for a program, check `~/.reimbursaurus/reference/<guide key>.fetched`. If it is missing or older than 30 days, run the refresh (next section).
- Portal Category, Type, and Description lists may differ by program. On the first draft for a new program, compare them with `category-map.md` and note differences there.
- Pick the best category and submit, whatever the program. If the guide for that child's program lists the item as not reimbursable, say so in the final report so the user knows a denial is likely.

## Multiple children
- Never hard-code one student. On step 1, open the student dropdown and read all options (format "Name : PROGRAM").
- Assign each receipt to a child before uploading. Sources, in order: a per-child subfolder (`<receipts folder>/<child>/`), a name in the file name, the user's chat. If none says, ask once per receipt.
- Keep a table: receipt file, child, program, age or grade. Use it for the learning text, since a preschooler and a 7th grader need different reasons.
- Run one draft per receipt, and set the student on step 1 of each draft. Confirm the student name on the Upload page ("Upload a receipt or invoice for <name>") and on the Summary.
- Programs can differ between children. See Programs above.
- Move the PDF to `Receipt_processed/` (or `<child>/Receipt_processed/`).

## Flow (verified)
Direct links to /SubmitReimbursement redirect to the Dashboard. Always start at Dashboard > Spending > Reimbursements > NEW.

| Step | Action |
|---|---|
| 1 Student | Open the dropdown, pick the student (format `<Student Name> : <PROGRAM>`), Continue |
| 2 Upload | `file_upload` the PDF to the hidden file input. Max 5MB. PDF, PNG, JPG. Continue |
| 3 Selection | The portal often cannot read the receipt. That is normal. Click Continue to enter details by hand |
| 4 Details | One "Item" block per line item. See below |
| 5 Additional Documents | Optional. Skip it and click CONTINUE TO SUMMARY |
| 6 Summary | Shows each item with tax and the total. Check the total against the receipt Grand Total. The SUBMIT FOR APPROVAL button carries a legal attestation (student not in full-time public school, funds used for authorized purposes). The user must say yes for each one before you click it |

## Step 4 fields (one block per book)
- Purchase Date: click the field, type digits only, like `10202026`.
- Invoice/Receipt #: the order number. Past entries left it blank, so either works.
- Learning text: book title plus one short reason (user choice). Example: "Charlotte's Web. Chapter book that builds reading comprehension for my 2nd grader."
- Category: Instructional Material. Type: Books. Description: Print/Textbooks/Workbooks/Other Books. Each choice reveals the next dropdown. The Category list is long, so use `find` then `scroll_to` then click the ref.
- Quantity 1. Cost per item: the item price.
- Money fields: triple-click the field, then type the number. Typing without selecting appends to "$0.00".
- Who did you pay: pick the vendor from the list (Amazon, Target, and so on).
- How will this help your student learn: use the item title plus one short learning reason that fits the child's age or grade. Ask the user once for each child's age or grade.
- Item URL: leave blank.
- Click ADD AN ITEM for each extra book on the same receipt.

## Tips
- The page can switch to a narrow layout. Coordinates then change. Take a screenshot before coordinate clicks.
- Clicking NEW creates a Draft each time. Delete stray empty drafts with the red X on the list. Ask first.
- To learn past conventions, open Reimbursements, click Details on an old row.
- After a receipt is submitted, move its PDF into `Receipt_processed/` in the same folder.

## Categories
See `category-map.md` for the full portal list, the item-to-category table, and a likely-ineligible list for information only. Check it before choosing a category for anything that is not a book. Pick the best fit and submit. Do not judge reimbursability: Step Up decides, and a denial is acceptable to the user.

## Refresh the reimbursable-items list
Step Up updates its purchasing guides often. Run `bash scripts/refresh-guide.sh` (all programs), or `bash scripts/refresh-guide.sh FES-UA` (one program), when: the user asks, a program's `~/.reimbursaurus/reference/<key>.fetched` is missing or older than 30 days, or a new school year starts.
1. The script downloads each guide to a temp folder, extracts the text, and prints the school year, the date, and a diff against the saved copy in `~/.reimbursaurus/reference/`.
2. UNCHANGED: nothing to do. CHANGED or FIRST SAVE: read the diff, then update `category-map.md` (item table, program differences, Description options, frequency limits). Wording-only diffs need no update.
   - "Saved as PDF" means `pdftotext` is not installed, so there is no text diff. Read the saved `.pdf` with the Read tool (no `pages` parameter) and compare it with `category-map.md` yourself. Do not ask the user to install anything.
3. If the school year shown is older than the current one, find the new guide link on https://www.stepupforstudents.org/purchasing-guides/ (and https://fcsua.org/FESUA/ for FES-UA), then edit the URL in `scripts/refresh-guide.sh`, or pass the link as an argument: `bash scripts/refresh-guide.sh <url>`.
4. The portal's dropdowns are the final word. After a refresh, open one draft and compare the Category, Type, and Description lists with `category-map.md`.

## Tax rule
Use true sales tax. Ask the user once for their county's combined rate (Florida state 6% plus county surtax) and save it for the session. Example: Miami-Dade County is 7%. Put tax on each item: price x rate, rounded to cents. Check that the item taxes add up to the receipt tax. If the receipt shows a different tax total, use the receipt. Example at 7%: $10.41 gets $0.73 and $9.99 gets $0.70, total $1.43.

## Robustness rules
- Start at the Reimbursements list. Resume existing drafts with Details before clicking NEW. This avoids stray drafts.
- Match each draft to its receipt: on step 2, read the uploaded file name (`find` the disabled textbox). Never guess from draft order.
- Sign-in page appears (timeout): stop, ask the user to sign in, then resume from the list. Never enter the password.
- After filling, check item taxes add up to the receipt tax and the page total equals the receipt Grand Total.
- Prefer `find` refs over pixel coordinates. The layout changes width. Wait 3 seconds after each Continue click, since the button shows "Loading".
- After submit, confirm the "Thank you" page shows a Reimbursement #, then move the PDF to `Receipt_processed/` and list the folder to verify.
- Vendor for marketplace sellers (for example Greenworld Books on Amazon): pick the payer on the receipt, Amazon.
- Delete empty drafts only after the user approves. The red X opens a confirm dialog naming the draft ID. Check the ID, then confirm.

## Submit approval
- The final Submit carries a legal attestation. Click it only after the user says yes in chat.
- "Submit after filling" covers only the receipts in that batch. Ask again for new receipts.
