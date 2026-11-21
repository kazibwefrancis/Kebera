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
  traffic-capture code, and contributions adding such code are rejected.
- **For AI agents:** `AGENTS.md` and `CLAUDE.md` instruct agents to refuse
  misuse and to stop when asked to act on networks or devices that aren't the user's.
- **In the project:** only the maintainer can merge changes into this repository.
  Pull requests, issues or discussions that seek to misuse Kebera are closed,
  and their authors may be blocked.
- **By law:** unauthorised access to computers and networks is a crime in Uganda
  (including under the Computer Misuse Act) and in most countries. Kebera's licence
  gives you no permission to break the law, and the authors accept no
  responsibility for misuse.

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
