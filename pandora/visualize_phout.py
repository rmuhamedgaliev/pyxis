#!/usr/bin/env python3
"""Visualize phout log files from Pandora load tests."""

import sys
import argparse
from pathlib import Path
from typing import List, Optional

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import matplotlib.gridspec as gridspec
from matplotlib.ticker import FuncFormatter

COLUMNS = [
    "timestamp", "tag", "interval_real", "connect_time", "send_time",
    "latency", "receive_time", "interval_event", "size_out", "size_in",
    "net_code", "proto_code",
]

US_TO_MS = 1_000


def load_phout(path: str) -> pd.DataFrame:
    df = pd.read_csv(path, sep="\t", names=COLUMNS, header=None)
    df["datetime"] = pd.to_datetime(df["timestamp"], unit="s")
    df["response_ms"] = df["interval_real"] / US_TO_MS
    df["latency_ms"] = df["latency"] / US_TO_MS
    df["success"] = (df["net_code"] == 0) & (df["proto_code"].between(200, 299))
    return df


def percentile_label(p: float) -> str:
    return f"p{int(p)}" if p == int(p) else f"p{p}"


def fmt_ms(x, _):
    if x >= 1000:
        return f"{x/1000:.1f}s"
    return f"{x:.0f}ms"


def plot_rps(ax: plt.Axes, df: pd.DataFrame) -> None:
    rps = df.set_index("datetime").resample("1s")["interval_real"].count()
    ax.fill_between(rps.index, rps.values, alpha=0.4, color="steelblue")
    ax.plot(rps.index, rps.values, color="steelblue", linewidth=1)
    ax.set_title("Requests per second")
    ax.set_ylabel("RPS")
    ax.set_xlabel("")
    ax.grid(axis="y", linestyle="--", alpha=0.5)


def plot_response_time(ax: plt.Axes, df: pd.DataFrame) -> None:
    resampled = df.set_index("datetime")["response_ms"].resample("1s")
    p50 = resampled.quantile(0.50)
    p95 = resampled.quantile(0.95)
    p99 = resampled.quantile(0.99)

    ax.fill_between(p99.index, p99.values, alpha=0.15, color="red", label="p99")
    ax.fill_between(p95.index, p95.values, alpha=0.2, color="orange", label="p95")
    ax.fill_between(p50.index, p50.values, alpha=0.35, color="green", label="p50")
    ax.plot(p99.index, p99.values, color="red", linewidth=0.8)
    ax.plot(p95.index, p95.values, color="orange", linewidth=0.8)
    ax.plot(p50.index, p50.values, color="green", linewidth=1)
    ax.yaxis.set_major_formatter(FuncFormatter(fmt_ms))
    ax.set_title("Response time over time")
    ax.set_ylabel("Response time")
    ax.legend(loc="upper right", fontsize=8)
    ax.grid(axis="y", linestyle="--", alpha=0.5)


def plot_error_rate(ax: plt.Axes, df: pd.DataFrame) -> None:
    resampled = df.set_index("datetime").resample("1s")
    total = resampled["success"].count()
    errors = resampled["success"].apply(lambda s: (s == False).sum())
    error_pct = (errors / total.replace(0, np.nan) * 100).fillna(0)

    ax.fill_between(error_pct.index, error_pct.values, alpha=0.4, color="crimson")
    ax.plot(error_pct.index, error_pct.values, color="crimson", linewidth=1)
    ax.set_title("Error rate")
    ax.set_ylabel("Error %")
    ax.set_ylim(bottom=0)
    ax.yaxis.set_major_formatter(FuncFormatter(lambda x, _: f"{x:.1f}%"))
    ax.grid(axis="y", linestyle="--", alpha=0.5)


def plot_histogram(ax: plt.Axes, df: pd.DataFrame) -> None:
    data = df["response_ms"].clip(upper=df["response_ms"].quantile(0.999))
    ax.hist(data, bins=80, color="steelblue", alpha=0.75, edgecolor="none")
    for p, color in [(50, "green"), (95, "orange"), (99, "red")]:
        val = np.percentile(df["response_ms"], p)
        ax.axvline(val, color=color, linestyle="--", linewidth=1.2,
                   label=f"p{p}={val:.0f}ms")
    ax.set_title("Response time distribution")
    ax.set_xlabel("Response time (ms)")
    ax.set_ylabel("Count")
    ax.xaxis.set_major_formatter(FuncFormatter(fmt_ms))
    ax.legend(fontsize=8)
    ax.grid(axis="y", linestyle="--", alpha=0.5)


def plot_per_tag(ax: plt.Axes, df: pd.DataFrame) -> None:
    tags = df["tag"].unique()
    percentiles = [50, 75, 90, 95, 99]
    data = {
        tag: [np.percentile(df.loc[df["tag"] == tag, "response_ms"], p) for p in percentiles]
        for tag in tags
    }

    x = np.arange(len(percentiles))
    width = 0.8 / max(len(tags), 1)
    colors = plt.cm.tab10(np.linspace(0, 0.9, len(tags)))

    for i, (tag, vals) in enumerate(data.items()):
        offset = (i - len(tags) / 2 + 0.5) * width
        ax.bar(x + offset, vals, width, label=tag, color=colors[i], alpha=0.85)

    ax.set_xticks(x)
    ax.set_xticklabels([f"p{p}" for p in percentiles])
    ax.set_title("Percentiles by scenario")
    ax.set_ylabel("Response time (ms)")
    ax.yaxis.set_major_formatter(FuncFormatter(fmt_ms))
    ax.legend(fontsize=7, loc="upper left")
    ax.grid(axis="y", linestyle="--", alpha=0.5)


def plot_proto_codes(ax: plt.Axes, df: pd.DataFrame) -> None:
    counts = df["proto_code"].value_counts().sort_index()
    colors = ["green" if 200 <= c < 300 else "red" for c in counts.index]
    bars = ax.bar([str(c) for c in counts.index], counts.values, color=colors, alpha=0.8)
    ax.set_title("HTTP/gRPC status codes")
    ax.set_xlabel("Status code")
    ax.set_ylabel("Count")
    for bar, val in zip(bars, counts.values):
        ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 0.5,
                str(val), ha="center", va="bottom", fontsize=8)
    ax.grid(axis="y", linestyle="--", alpha=0.5)


def print_summary(df: pd.DataFrame, name: str) -> None:
    total = len(df)
    errors = (~df["success"]).sum()
    duration = df["datetime"].max() - df["datetime"].min()
    avg_rps = total / max(duration.total_seconds(), 1)

    print(f"\n{'='*50}")
    print(f"  {name}")
    print(f"{'='*50}")
    print(f"  Total requests : {total:,}")
    print(f"  Duration       : {duration}")
    print(f"  Avg RPS        : {avg_rps:.1f}")
    print(f"  Errors         : {errors:,} ({errors/total*100:.2f}%)")
    print(f"  Response time  :")
    for p in [50, 75, 90, 95, 99]:
        val = np.percentile(df["response_ms"], p)
        print(f"    p{p:<3} = {val:>8.1f} ms")
    print()


def visualize(paths: List[str], output: Optional[str]) -> None:
    all_dfs = {}
    for path in paths:
        name = Path(path).stem
        df = load_phout(path)
        all_dfs[name] = df
        print_summary(df, name)

    for name, df in all_dfs.items():
        fig = plt.figure(figsize=(16, 12))
        fig.suptitle(f"Phout report: {name}", fontsize=14, fontweight="bold")

        gs = gridspec.GridSpec(3, 2, figure=fig, hspace=0.45, wspace=0.35)

        plot_rps(fig.add_subplot(gs[0, 0]), df)
        plot_response_time(fig.add_subplot(gs[0, 1]), df)
        plot_error_rate(fig.add_subplot(gs[1, 0]), df)
        plot_histogram(fig.add_subplot(gs[1, 1]), df)
        plot_per_tag(fig.add_subplot(gs[2, 0]), df)
        plot_proto_codes(fig.add_subplot(gs[2, 1]), df)

        if output:
            out_path = Path(output) / f"{name}.png"
            out_path.parent.mkdir(parents=True, exist_ok=True)
            fig.savefig(out_path, dpi=150, bbox_inches="tight")
            print(f"Saved: {out_path}")
        else:
            plt.show()

        plt.close(fig)


def main() -> None:
    parser = argparse.ArgumentParser(description="Visualize phout load test logs")
    parser.add_argument("files", nargs="+", help="Phout log file(s)")
    parser.add_argument("-o", "--output", metavar="DIR",
                        help="Save PNGs to this directory instead of showing interactively")
    args = parser.parse_args()

    missing = [f for f in args.files if not Path(f).exists()]
    if missing:
        print(f"Files not found: {missing}", file=sys.stderr)
        sys.exit(1)

    visualize(args.files, args.output)


if __name__ == "__main__":
    main()
