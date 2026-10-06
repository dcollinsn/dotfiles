# Saved printer setup

On a Manjaro/Arch laptop with CUPS 2.x, clone this repository and run:

```sh
./install_printers.sh
```

The installer uses sudo for packages, services, and CUPS configuration. All
queues can be created with the printers unplugged. Running it again restores
the saved settings. Run it as your normal login user so your CUPS user defaults
are restored too.

| Queue | Printer | Saved defaults |
| --- | --- | --- |
| `IPP_HP_4001` | HP 4001, serial VNL0274691 | Letter, grayscale, normal quality; default printer |
| `IPP_HP_M607_1` | M607, serial PHBCT9C122 | Letter, grayscale, high quality, 1200 dpi |
| `IPP_HP_M607_2` | M607, serial PHBCT9C124 | Same profile and defaults as M607 1 |
| `Brother2270` | Brother HL-2270DW at 192.168.1.244 | brlaser driver |

The HP profiles were exported from working CUPS queues on October 6, 2026.
Both M607s use `profiles/HP-M607.ppd`. The 4001 uses `profiles/HP-4001.ppd`.
Laptop-specific supply and translation URLs were removed; the saved profiles
use their embedded English labels. These profiles require the CUPS 2.x
PPD/filter workflow.

`printers.conf` records stable DNS-SD identities rather than laptop-specific
localhost ports. ipp-usb allocates ports on each laptop and advertises the
printers through Avahi. This follows the
[ipp-usb discovery model](https://github.com/OpenPrinting/ipp-usb/blob/master/ipp-usb.8.md).
Use the distribution's default ipp-usb configuration: DNS-SD enabled and
`interface = loopback`. An existing customized configuration is left intact.

## Store a job on either M607

Export the document as a PDF, then run:

```sh
m607-store-only document.pdf
m607-store-only --printer 2 --copies 80 --name 'Monthly reports' document.pdf
```

The helper automatically selects the saved M607 connected through USB. If both
are connected, specify `--printer 1` or `--printer 2`. It also works directly
from this checkout before installation:

```sh
./m607-store-only.sh --validate document.pdf
./m607-store-only.sh document.pdf
```

`--validate` sends only Validate-Job: no document upload and no created job.
Every submission first validates exactly the same storage and quality
attributes. It requires `successful-ok` and requests attribute fidelity so
unsupported settings should be rejected. It then submits once and shows the
job ID. It never falls back to normal printing or retries automatically.
If the submission fails, inspect the printer before trying again because a
lost response can still mean the printer received the job.

This preserves the previous HP-specific `job-storage` collection in the
operation attributes, including `job-storage-disposition = store-only`, plus
high quality, 1200 dpi, and `hp-print-quality-mode = 4`. The helper uses
[CUPS ipptool](https://openprinting.github.io/cups/doc/man-ipptool.html)
directly against the discovered printer endpoint. An ordinary `lp` command or
a CUPS hold option does not provide this saved workflow.

Jobs are stored with **public access**, matching the previous command; there
is no PIN. Release them using **Retrieve from Device Memory** on the M607's
control panel. Storage availability and capacity depend on the printer's
hardware and settings. This setup does not claim store-only support for the
4001.

## Check a new laptop

```sh
lpstat -t
lpoptions -p IPP_HP_M607_1 -l
lpoptions -p IPP_HP_M607_2 -l
ippfind -T 5 _ipp._tcp --local --print
m607-store-only --printer 1 --validate document.pdf
```

For the first hardware check on each M607, submit a one-page PDF with one copy.
Confirm that no paper emerges, that the job appears in device memory, and that
releasing it at the panel prints the page. Validate-Job acceptance alone cannot
prove physical storage behavior. No HP printer was discoverable while this
setup was saved, so that hardware check is still required.

If discovery fails, check USB, printer power, and
`systemctl status ipp-usb avahi-daemon cups`. Don't substitute a remembered
60000-series port: it can belong to a different printer on another laptop.
For a replacement printer with a different serial number, update its service
name and URI in `printers.conf` and rerun the installer.

`m607-store-only.ipp` and `m607-validate-storage.ipp` are runtime request
templates used by the helper, and must be included when copying this setup.
