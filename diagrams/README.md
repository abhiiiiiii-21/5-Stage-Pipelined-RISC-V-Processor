# Diagram Sources

The Mermaid source files describe the datapath and hazard paths:

- `datapath.mmd`: complete five-stage data path and control connections.
- `pipeline_timing.mmd`: normal, load-use, and taken-branch timing summary.
- `hazard_forwarding.mmd`: EX/MEM and MEM/WB forwarding priority.

Render them with Mermaid CLI, Mermaid Live, or an editor extension. PNG exports and
GTKWave screenshots should be generated locally after the system tests have run.

With Mermaid CLI installed, PNG exports can be generated from the repository root:

```sh
npx --yes @mermaid-js/mermaid-cli -i diagrams/datapath.mmd -o diagrams/datapath.png
npx --yes @mermaid-js/mermaid-cli -i diagrams/pipeline_timing.mmd -o diagrams/pipeline_timing.png
npx --yes @mermaid-js/mermaid-cli -i diagrams/hazard_forwarding.mmd -o diagrams/hazard_forwarding.png
```

The generated PNGs are presentation artifacts and should be reviewed before recording
the demonstration video.
