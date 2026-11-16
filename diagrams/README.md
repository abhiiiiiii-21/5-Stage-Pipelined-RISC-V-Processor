# Diagram Sources

The Mermaid source files describe the datapath and hazard paths:

- `datapath.mmd`: complete five-stage data path and control connections.
- `pipeline_timing.mmd`: normal, load-use, and taken-branch timing summary.
- `hazard_forwarding.mmd`: EX/MEM and MEM/WB forwarding priority.

Render them with Mermaid CLI, Mermaid Live, or an editor extension. PNG exports and
GTKWave screenshots should be generated locally after the system tests have run.
