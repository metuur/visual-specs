## Install (on the other computer)

Copy that one `.tgz` over (AirDrop / USB / `scp`), then:

```bash
npm install -g ./metuur-visual-spec-0.1.3.tgz
visual-spec --version
visual-spec .          # run it on any directory
```

The `visual-spec` command is now on the other machine's PATH (**Node ≥ 18**
required there).

---

## Notes & alternatives

- **Why not just zip the whole folder?** You'd be copying `node_modules` and
  source unnecessarily. If you do want a plain zip, build first and zip only what
  ships:

  ```bash
  npm run build && zip -r visual-spec.zip dist package.json
  ```

  Then on the other side: `npm install -g /path/to/unzipped-folder`. The `.tgz`
  route is simpler and produces an identical result.
