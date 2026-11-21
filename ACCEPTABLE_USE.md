# Acceptable use policy

## Kebera is not a hacking tool

Kebera exists to help people diagnose **their own** internet connection and hold
their providers to account with evidence. It is **not** a hacking tool, and it
must never be used or modified to become one.

**Misuse or perversion of Kebera is not tolerated.**

## Allowed

- Diagnosing your own home or office connection, or one you have the owner's
  permission to diagnose.
- Opening and signing in to **your own** router, indoor unit, outdoor unit, fibre
  modem or provider account pages, **with your own credentials, typed by you**, to
  read their status (signal, uptime, data usage, logs).
- Letting an AI agent read those pages **after you have signed in yourself**.
- Changing a setting on your own equipment when you understand it and choose to,
  for example the Wi-Fi channel or splitting 2.4 GHz and 5 GHz names.
- Sharing your own reports with your provider, the regulator or the community.
- Using, studying, modifying and redistributing the code under the
  [MIT licence](LICENSE), in line with this policy.

## Not allowed

- Accessing, probing, scanning or testing **any network, router or device that
  isn't yours** or that you don't have permission to test.
- Guessing, cracking, brute-forcing or trying default passwords, or bypassing a
  login page in any way.
- Exploiting vulnerabilities, using hidden or undocumented admin functions, or
  altering firmware.
- Capturing, intercepting or reading other people's traffic, or connecting to
  other people's Wi-Fi without permission.
- Collecting other people's information, such as neighbours' network details,
  device identifiers or locations.
- Jamming, interfering with or transmitting on radio frequencies, or helping
  anyone do so.
- Modifying Kebera to do any of the above and presenting it as Kebera.
- Giving an AI agent instructions to use Kebera for any of the above.

## How this is enforced

- **By design:** Kebera is read-only. It contains no login, password, exploit or
  traffic-capture code, and contributions adding such code are rejected. The
  scripts find your own equipment automatically (your default gateway and the next
  private hop) and **have no option to aim them at anything else**. A built-in
  safety check stops the script if any target isn't your own local equipment or
  one of the fixed public test services.
- **Transparently, not hidden:** the safeguards are written in plain view, on
  purpose. Hidden or scrambled code would make Kebera look like malware, get it
  flagged by antivirus software, and break the trust that open source depends on.
  Anyone *can* change open-source code, so the real protections are: no harmful
  capability in the first place, a visible safety check, and the official
  repository as the trusted source. **Download Kebera only from
  github.com/kazibwefrancis/kebera**; copies elsewhere may have been altered.
- **For AI agents:** `AGENTS.md` and `CLAUDE.md` instruct agents to refuse
  misuse and to stop when asked to act on networks or devices that aren't the user's.
- **In the project:** only the maintainer can merge changes into this repository.
  Pull requests, issues or discussions that seek to misuse Kebera are closed,
  and their authors may be blocked.
- **By law:** unauthorised access to computers and networks, interfering with
  radio signals and misusing personal data are crimes in Uganda and in most
  countries (see below). Kebera's licence gives you no permission to break the
  law, and the authors accept no responsibility for misuse.

## Laws that apply, wherever you are

Kebera is used in Uganda and beyond. **You must follow the laws of the country you
are in**, and those of any country where the equipment or network is located.
Examples (not a complete list, and not legal advice):

| Where | Examples of laws that make misuse a crime or regulate data and radio |
|---|---|
| **Uganda** | Computer Misuse Act, 2011 (as amended); Data Protection and Privacy Act, 2019; Uganda Communications Act, 2013 (radio spectrum and interference) |
| **Kenya** | Computer Misuse and Cybercrimes Act, 2018; Data Protection Act, 2019 |
| **Tanzania** | Cybercrimes Act, 2015 |
| **Rwanda** | Law on the prevention and punishment of cyber crimes, 2018 |
| **Nigeria** | Cybercrimes (Prohibition, Prevention, etc.) Act, 2015 |
| **South Africa** | Cybercrimes Act, 2020; Protection of Personal Information Act (POPIA) |
| **United Kingdom** | Computer Misuse Act 1990; Wireless Telegraphy Act 2006 |
| **United States** | Computer Fraud and Abuse Act (18 U.S.C. § 1030); federal rules prohibiting signal jammers |
| **European Union** | Directive 2013/40/EU on attacks against information systems; General Data Protection Regulation (GDPR) |
| **International** | Council of Europe Convention on Cybercrime (Budapest Convention); African Union Convention on Cyber Security and Personal Data Protection (Malabo Convention); ITU Radio Regulations (harmful interference) |

The principles are the same almost everywhere:

1. **Only access what you own or have clear permission to access.** "It was easy" or
   "it had a default password" is never permission.
2. **Don't interfere with radio communications.** Jammers and unapproved signal
   boosters are illegal in most countries.
3. **Respect other people's data.** Don't collect, keep or share other people's
   network names, device identifiers, traffic or locations.
4. **When in doubt, don't.** Ask the owner, or ask a lawyer.

If any part of this policy conflicts with the law where you are, the stricter rule applies.

## A note on the licence

Kebera is open source under the MIT licence, so anyone may use, copy, modify and
share it. An open-source licence can't legally forbid particular uses without
ceasing to be open source, so this policy sets the rules for the **Kebera
project and community**: what is accepted here, what agents are instructed to do,
and what the maintainer will merge. Anyone who modifies Kebera for misuse acts
outside this project, on their own legal responsibility.

## Reporting misuse

If you see Kebera being misused, or a fork marketed for hacking, report it through
the repository's **Security** tab (private vulnerability reporting) or contact the
maintainer privately.
