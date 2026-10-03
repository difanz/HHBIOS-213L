# Protected-mode VESA renderer

A DPMI or VCPI renderer was not built. `VESA.COM` does not load a DOS
extender, CWSDPMI, or any other host, and it does not call VCPI or DPMI.
Direct-color glyphs use a private short CR0 session when PE is clear.
V86, including EMM386 and JEMM, stays on the 64 KiB window. Install still
requires the EMS manager named in `qa/VBE-RULES.md`.
