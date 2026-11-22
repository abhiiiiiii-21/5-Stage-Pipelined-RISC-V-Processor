#!/usr/bin/env python3
"""
Waveform Generator for 5-Stage Pipelined RISC-V Processor.
Parses simulation VCD files and renders authentic GTKWave-style waveform
screenshots with high-contrast signal traces, hex bus envelopes, and timing markers.
Outputs saved to diagrams/waveforms/*.png.
"""

import os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.patches as patches

# Color palette matching GTKWave theme
COLOR_BG = '#0f111a'          # Deep dark canvas background
COLOR_PANEL_BG = '#1a1c25'    # Signal names left panel
COLOR_GRID = '#2a2d3d'        # Time grid lines
COLOR_TEXT_MAIN = '#e0e6ed'   # Main text color
COLOR_TEXT_MUTED = '#8892b0'  # Secondary/ruler text
COLOR_BUS_BORDER = '#00f0ff'  # Cyan for multi-bit bus transitions
COLOR_BUS_FILL = '#002b36'    # Semi-dark fill inside multi-bit buses
COLOR_BUS_TEXT = '#a6e22e'    # Green/Yellow text inside buses
COLOR_CLK = '#ffffff'         # Bright white clock
COLOR_WARN_RED = '#ff3366'    # Red for flushes / stalls / pc_write=0
COLOR_FWD_GOLD = '#ffcc00'    # Gold/Yellow for forwarding
COLOR_BRANCH = '#bd93f9'      # Purple for branch/jump signals

def parse_vcd_signals(vcd_path, target_scope, signal_names):
    """
    Parses a VCD file and extracts transitions for target signals within target_scope.
    Returns: {signal_name: [(time_ps, val_str), ...]}
    """
    sym_to_sig = {}
    with open(vcd_path, 'r') as f:
        scope = []
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.startswith('$scope'):
                scope.append(line.split()[2])
            elif line.startswith('$upscope'):
                if scope:
                    scope.pop()
            elif line.startswith('$var'):
                parts = line.split()
                # parts: $var wire 32 B if_pc [31:0] $end
                cur_scope = '.'.join(scope)
                if cur_scope.endswith(target_scope):
                    sig_name = parts[4]
                    sym = parts[3]
                    if sig_name in signal_names:
                        sym_to_sig[sym] = sig_name
            elif line.startswith('$enddefinitions'):
                break

        # Collect transitions
        cur_time = 0
        raw_traces = {sig: [] for sig in signal_names}
        for line in f:
            line = line.strip()
            if not line:
                continue
            if line.startswith('#'):
                cur_time = int(line[1:])
            elif line.startswith('b'):
                parts = line.split()
                val = parts[0][1:]
                sym = parts[1]
                if sym in sym_to_sig:
                    raw_traces[sym_to_sig[sym]].append((cur_time, val))
            elif len(line) >= 2 and line[1:] in sym_to_sig:
                val = line[0]
                sym = line[1:]
                raw_traces[sym_to_sig[sym]].append((cur_time, val))

    return raw_traces

def get_value_at(trace, time_ps, default='0'):
    """Returns the signal value active at time_ps."""
    last_val = default
    for t, val in trace:
        if t <= time_ps:
            last_val = val
        else:
            break
    return last_val

def render_gtkwave_screenshot(
    vcd_path,
    target_scope,
    signals_spec,
    start_time_ps,
    end_time_ps,
    title,
    output_png_path,
    highlight_boxes=None
):
    """
    Renders a GTKWave-styled waveform screenshot from start_time_ps to end_time_ps.
    signals_spec: list of tuples: (sig_name, display_label, is_bus, color)
    highlight_boxes: list of tuples: (t_start, t_end, label, color)
    """
    sig_names = [spec[0] for spec in signals_spec]
    raw_traces = parse_vcd_signals(vcd_path, target_scope, sig_names)

    num_signals = len(signals_spec)
    track_height = 0.8
    track_gap = 0.3
    total_height = num_signals * (track_height + track_gap) + 1.6

    fig, ax = plt.subplots(figsize=(14, 0.65 * total_height), dpi=180)
    fig.patch.set_facecolor(COLOR_BG)
    ax.set_facecolor(COLOR_BG)

    # Time calculations
    step_ps = 500  # sampling interval for smooth rendering
    time_pts = list(range(start_time_ps, end_time_ps + 1, step_ps))
    duration_ns = (end_time_ps - start_time_ps) / 1000.0

    # Draw vertical grid for clock periods (10ns = 10000ps)
    first_clk_edge = ((start_time_ps + 9999) // 10000) * 10000
    for clk_t in range(first_clk_edge, end_time_ps + 1, 10000):
        t_ns = (clk_t - start_time_ps) / 1000.0
        ax.axvline(x=t_ns, color=COLOR_GRID, linestyle='--', linewidth=0.8, alpha=0.7, zorder=1)
        cycle_idx = clk_t // 10000
        ax.text(t_ns + 0.1, total_height - 0.7, f"C{cycle_idx}\n{clk_t//1000}ns",
                color=COLOR_TEXT_MUTED, fontsize=7, fontfamily='monospace', va='bottom', ha='left')

    # Draw highlight boxes if any
    if highlight_boxes:
        for t_s, t_e, h_label, h_color in highlight_boxes:
            t_s_ns = (t_s - start_time_ps) / 1000.0
            t_e_ns = (t_e - start_time_ps) / 1000.0
            rect = patches.Rectangle((t_s_ns, 0), t_e_ns - t_s_ns, total_height - 0.8,
                                     facecolor=h_color, alpha=0.12, edgecolor=h_color,
                                     linestyle=':', linewidth=1.5, zorder=2)
            ax.add_patch(rect)
            ax.text((t_s_ns + t_e_ns) / 2.0, total_height - 0.3, h_label,
                    color=h_color, fontsize=8.5, fontweight='bold', fontfamily='sans-serif',
                    ha='center', va='bottom', zorder=5)

    # Render each signal track
    for idx, (sig_name, display_label, is_bus, color) in enumerate(signals_spec):
        y_base = (num_signals - 1 - idx) * (track_height + track_gap) + 0.4
        trace = raw_traces.get(sig_name, [])

        # Label on left (simulate GTKWave left panel)
        ax.text(-0.3, y_base + track_height / 2.0, display_label,
                color=color if color != COLOR_CLK else COLOR_TEXT_MAIN,
                fontsize=8.5, fontweight='bold', fontfamily='monospace',
                ha='right', va='center')

        if not is_bus:
            # 1-bit binary signal (high/low square wave)
            xs = []
            ys = []
            cur_y = 0.0
            for t in time_pts:
                val = get_value_at(trace, t, '0')
                lvl = y_base + (track_height if val == '1' else 0.05 * track_height)
                t_ns = (t - start_time_ps) / 1000.0
                if xs and lvl != cur_y:
                    xs.append(t_ns)
                    ys.append(cur_y)
                    xs.append(t_ns)
                    ys.append(lvl)
                else:
                    xs.append(t_ns)
                    ys.append(lvl)
                cur_y = lvl

            ax.plot(xs, ys, color=color, linewidth=1.8, zorder=3)
            # Add subtle fill under waveform for binary high
            ax.fill_between(xs, y_base, ys, color=color, alpha=0.15, zorder=2)

        else:
            # Multi-bit bus: render hexagonal bus intervals
            # Find change points within [start_time_ps, end_time_ps]
            filtered = [(t, v) for t, v in trace if t <= end_time_ps]
            if not filtered or filtered[0][0] > start_time_ps:
                init_val = get_value_at(trace, start_time_ps, '0')
                filtered = [(start_time_ps, init_val)] + [x for x in filtered if x[0] > start_time_ps]

            intervals = []
            for i in range(len(filtered)):
                t_start = max(start_time_ps, filtered[i][0])
                t_end = min(end_time_ps, filtered[i+1][0] if i + 1 < len(filtered) else end_time_ps)
                val = filtered[i][1]
                if t_start < t_end:
                    intervals.append((t_start, t_end, val))

            for t_s, t_e, val in intervals:
                ts_ns = (t_s - start_time_ps) / 1000.0
                te_ns = (t_e - start_time_ps) / 1000.0
                width = te_ns - ts_ns
                if width <= 0:
                    continue

                # Format value as uppercase hex
                try:
                    ival = int(val, 2)
                    if 'pc' in sig_name or 'instr' in sig_name or 'result' in sig_name or 'data' in sig_name:
                        hex_str = f"0x{ival:08X}" if ival > 0xF else f"0x{ival:X}"
                    else:
                        hex_str = f"{ival}"
                except ValueError:
                    hex_str = str(val)

                # Draw bus polygon
                slant = min(0.3, width * 0.25)
                poly_pts = [
                    (ts_ns + slant, y_base + track_height),
                    (te_ns - slant, y_base + track_height),
                    (te_ns, y_base + track_height / 2.0),
                    (te_ns - slant, y_base),
                    (ts_ns + slant, y_base),
                    (ts_ns, y_base + track_height / 2.0)
                ]
                polygon = patches.Polygon(poly_pts, closed=True,
                                          facecolor=COLOR_BUS_FILL,
                                          edgecolor=color, linewidth=1.3, zorder=3)
                ax.add_patch(polygon)

                # Centered hex text if width allows
                if width > 0.8:
                    ax.text(ts_ns + width / 2.0, y_base + track_height / 2.0, hex_str,
                            color=COLOR_BUS_TEXT if color == COLOR_BUS_BORDER else color,
                            fontsize=7.5, fontweight='bold', fontfamily='monospace',
                            ha='center', va='center', zorder=4)

    # Axes decorations
    ax.set_xlim(-2.2, duration_ns + 0.5)
    ax.set_ylim(-0.2, total_height)
    ax.set_xlabel("Time (ns)", color=COLOR_TEXT_MUTED, fontsize=9, labelpad=8)
    ax.set_title(title, color=COLOR_TEXT_MAIN, fontsize=11, fontweight='bold', pad=14, loc='left')

    # Remove standard tick frames, keep clean GTKWave look
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.spines['left'].set_visible(False)
    ax.spines['bottom'].set_color(COLOR_GRID)
    ax.tick_params(axis='x', colors=COLOR_TEXT_MUTED, labelsize=8)
    ax.tick_params(axis='y', left=False, labelleft=False)

    plt.tight_layout()
    os.makedirs(os.path.dirname(output_png_path), exist_ok=True)
    plt.savefig(output_png_path, facecolor=fig.get_facecolor(), edgecolor='none', dpi=180)
    plt.close()
    print(f"Generated: {output_png_path}")

def generate_all_waveforms():
    # Common signal specifications for pipeline:
    signals_pipeline = [
        ('clk', 'clk', False, COLOR_CLK),
        ('if_pc', 'if_pc[31:0]', True, COLOR_BUS_BORDER),
        ('id_instr', 'id_instr[31:0]', True, COLOR_BUS_BORDER),
        ('ex_result', 'ex_result[31:0]', True, COLOR_BUS_BORDER),
        ('wb_data', 'wb_data[31:0]', True, '#50fa7b'),
        ('forward_a', 'forward_a[1:0]', True, COLOR_FWD_GOLD),
        ('forward_b', 'forward_b[1:0]', True, COLOR_FWD_GOLD),
        ('pc_write', 'pc_write', False, '#50fa7b'),
        ('if_id_flush', 'if_id_flush', False, COLOR_WARN_RED),
        ('id_ex_flush', 'id_ex_flush', False, COLOR_WARN_RED),
        ('pc_src', 'pc_src', False, COLOR_BRANCH)
    ]

    # 1. Forwarding (Test 3)
    # Cycles 3 to 8 (30ns to 85ns = 30000ps to 85000ps)
    render_gtkwave_screenshot(
        vcd_path='simulation/build/tb_riscv_top_3.vcd',
        target_scope='dut',
        signals_spec=signals_pipeline,
        start_time_ps=25000,
        end_time_ps=85000,
        title='GTKWave: Test 3 Data Forwarding (EX/MEM and MEM/WB forwarding to EX stage)',
        output_png_path='diagrams/waveforms/forwarding.png',
        highlight_boxes=[
            (50000, 70000, 'EX/MEM Forward (forward_a=2)', COLOR_FWD_GOLD),
            (70000, 80000, 'MEM/WB Forward (forward_a=1)', COLOR_FWD_GOLD)
        ]
    )

    # 2. Load-Use Stall (Test 4)
    # Cycles 3 to 9 (30ns to 90ns = 30000ps to 90000ps)
    render_gtkwave_screenshot(
        vcd_path='simulation/build/tb_riscv_top_4.vcd',
        target_scope='dut',
        signals_spec=signals_pipeline,
        start_time_ps=25000,
        end_time_ps=85000,
        title='GTKWave: Test 4 Load-Use Hazard Stall (1-cycle bubble + MEM forwarding)',
        output_png_path='diagrams/waveforms/load_use_stall.png',
        highlight_boxes=[
            (50000, 60000, '1-Cycle Stall (pc_write=0, id_ex_flush=1)', COLOR_WARN_RED),
            (65000, 78000, 'Forward Loaded Value (forward_a=1, forward_b=1)', COLOR_FWD_GOLD)
        ]
    )

    # 3. Branch/Jump Flush (Test 5)
    # Cycles 3 to 9 (30ns to 90ns = 30000ps to 90000ps)
    render_gtkwave_screenshot(
        vcd_path='simulation/build/tb_riscv_top_5.vcd',
        target_scope='dut',
        signals_spec=signals_pipeline,
        start_time_ps=25000,
        end_time_ps=95000,
        title='GTKWave: Test 5 Branch / Jump Flush (Predict Not-Taken, 2-cycle penalty)',
        output_png_path='diagrams/waveforms/branch_flush.png',
        highlight_boxes=[
            (50000, 60000, 'Branch Resolved Taken (pc_src=1 -> Flush IF/ID & ID/EX)', COLOR_WARN_RED),
            (80000, 90000, 'JAL / JALR Taken (pc_src=1 -> 2 Bubbles Flushed)', COLOR_BRANCH)
        ]
    )

    # 4. Benchmark Sort Loop (bench_sort)
    # Cycles 197 to 209 (1970000ps to 2090000ps)
    render_gtkwave_screenshot(
        vcd_path='simulation/build/bench_sort_pipeline.vcd',
        target_scope='dut',
        signals_spec=signals_pipeline,
        start_time_ps=1970000,
        end_time_ps=2090000,
        title='GTKWave: bench_sort Inner Loop (Load-Use Stall, Forwarding & Branch Flushes)',
        output_png_path='diagrams/waveforms/bench_sort_loop.png',
        highlight_boxes=[
            (2005000, 2025000, 'Load-Use Stall on loaded a[j+1]', COLOR_WARN_RED),
            (2030000, 2045000, 'Branch Taken Flush (noswap)', COLOR_BRANCH),
            (2065000, 2085000, 'Inner Loop Branch Flush', COLOR_BRANCH)
        ]
    )

if __name__ == '__main__':
    generate_all_waveforms()
