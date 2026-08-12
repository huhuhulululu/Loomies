let meta = #{
    name: "cloth-polish-parallel",
    description: "Parallel full-function polish for cloth paper-doll wear (slots, UI, tests)",
    when_to_use: "User asks to continue full-function polish / paper-doll dressing with parallel lanes",
    phases: [
        #{ title: "Scan", detail: "parallel read-only gap scan on three wear lanes" },
        #{ title: "Fix", detail: "parallel minimal fixes for top gaps (worktree isolation)" },
        #{ title: "Verify", detail: "run package tests and synthesize status" },
    ],
};

// args.root optional; default cloth repo
let root = if args == () { () } else { args.root };
if root == () { root = "/Users/ping/code/cloth"; }
let max_gaps = if args == () { () } else { args.max_gaps };
if max_gaps == () { max_gaps = 2; }

let gap_schema = #{
    "type": "object",
    "required": ["lane", "gaps", "healthy"],
    "properties": #{
        "lane": #{ "type": "string" },
        "healthy": #{ "type": "boolean" },
        "gaps": #{
            "type": "array",
            "maxItems": 4,
            "items": #{
                "type": "object",
                "required": ["id", "file", "issue", "severity"],
                "properties": #{
                    "id": #{ "type": "string" },
                    "file": #{ "type": "string" },
                    "issue": #{ "type": "string" },
                    "severity": #{ "type": "string", "enum": ["p0", "p1", "p2"] },
                },
            },
        },
        "notes": #{ "type": "string" },
    },
};

let fix_schema = #{
    "type": "object",
    "required": ["lane", "changed", "summary", "files"],
    "properties": #{
        "lane": #{ "type": "string" },
        "changed": #{ "type": "boolean" },
        "summary": #{ "type": "string" },
        "files": #{ "type": "array", "items": #{ "type": "string" } },
        "test_hint": #{ "type": "string" },
    },
};

let verify_schema = #{
    "type": "object",
    "required": ["core_ok", "model_ok", "ui_ok", "summary"],
    "properties": #{
        "core_ok": #{ "type": "boolean" },
        "model_ok": #{ "type": "boolean" },
        "ui_ok": #{ "type": "boolean" },
        "summary": #{ "type": "string" },
        "failures": #{ "type": "string" },
    },
};

// Product hard rails — every agent prompt must restate these
let rails = "";
rails += "REPO=" + root + ". Product rails (do not violate): ";
rails += "(1) layered paper-doll, NOT selfie VTON; ";
rails += "(2) D63/D64 catalog basewear only — do NOT reopen full-nude hard gate; ";
rails += "(3) ClosetCore pure Swift Foundation-only; ";
rails += "(4) surgical diffs only; no drive-by refactors; ";
rails += "(5) use read_file/grep/run_terminal_command — never answer from memory alone. ";

phase("Scan");
log("Scanning three wear lanes in parallel under " + root);

let scan_jobs = [];

let p_slots = rails;
p_slots += "LANE=slots-composer. Inspect paper-doll slot/layer correctness. ";
p_slots += "Read and grep: Packages/ClosetCore/.../BodyAvatarLayout.swift (mapSlot, displaySlot, zIndex, fullCanvas); ";
p_slots += "Packages/ClosetModel/.../OutfitAvatarComposer.swift; DemoSeedService.swift; ";
p_slots += "related *Tests*. Report at most 4 concrete gaps as {id,file,issue,priority}. ";
p_slots += "healthy=true only if tee+blazer+bottom+shoes can stack, dress drops top/bottom, displaySlot corrects dirty tops. ";
p_slots += "Empty gaps only after you actually read the files.";
scan_jobs.push(#{
    prompt: p_slots,
    label: "scan:slots",
    capability_mode: "read-only",
    output_schema: gap_schema,
});

let p_ui = rails;
p_ui += "LANE=ui-hero. Inspect Today hero / BodyAvatarView wear UX. ";
p_ui += "Read: Packages/ClosetUI/.../BodyAvatarView.swift (garmentLayer, yawDegrees/snapYaw, garmentYawOpacity); ";
p_ui += "CopilotView.swift (heroLayers, empty overlay, wearSummary subtitle). ";
p_ui += "Report gaps: side-angle fade, empty-layer hint, image load path, fit caption. ";
p_ui += "healthy=true only if front shows layers, empty look shows undressed hint, drag syncs yawDegrees.";
scan_jobs.push(#{
    prompt: p_ui,
    label: "scan:ui",
    capability_mode: "read-only",
    output_schema: gap_schema,
});

let p_tests = rails;
p_tests += "LANE=tests-smoke. Inspect wear-path tests coverage. ";
p_tests += "Read: ClosetCoreTests/BodyAvatarLayoutTests.swift; ClosetModelTests/OutfitAvatarComposerTests.swift; ";
p_tests += "grep workLookStacks, displaySlot, demoSeed, MannequinGarmentVisibility. ";
p_tests += "Report missing cases (priority p0 if regression risk). ";
p_tests += "healthy=true if work look stack + displaySlot dirty + demo seed wearable tests exist.";
scan_jobs.push(#{
    prompt: p_tests,
    label: "scan:tests",
    capability_mode: "read-only",
    output_schema: gap_schema,
});

let scans = parallel(scan_jobs);

let all_gaps = [];
let scan_notes = [];
let i = 0;
for r in scans {
    if r == () || !r.success {
        scan_notes.push("scan_slot_" + i.to_string() + "_failed");
    } else {
        if r.output.notes != () && r.output.notes != "" {
            scan_notes.push(r.output.notes);
        }
        if r.output.gaps != () {
            for g in r.output.gaps {
                // scope: only under Packages/
                if g.file != () {
                    let f = g.file;
                    if f.contains("Packages/") || f.contains("docs/") {
                        all_gaps.push(g);
                    }
                }
            }
        }
    }
    i += 1;
}

log("Collected " + all_gaps.len().to_string() + " in-scope gaps");

// Rank: take up to max_gaps p0 then p1 (simple pass)
let to_fix = [];
for g in all_gaps {
    if to_fix.len() >= max_gaps { break; }
    if g.priority == "p0" { to_fix.push(g); }
}
for g in all_gaps {
    if to_fix.len() >= max_gaps { break; }
    if g.priority == "p1" {
        let already = false;
        for t in to_fix {
            if t.id == g.id { already = true; }
        }
        if !already { to_fix.push(g); }
    }
}
for g in all_gaps {
    if to_fix.len() >= max_gaps { break; }
    let already = false;
    for t in to_fix {
        if t.id == g.id { already = true; }
    }
    if !already { to_fix.push(g); }
}

if to_fix.len() == 0 {
    let path = write_scratch_file("polish-report.md", "# cloth-polish-parallel\n\nNo actionable gaps. Wear lanes healthy.\n");
    complete(#{
        summary: "No actionable gaps — wear polish lanes healthy",
        gaps_found: all_gaps.len(),
        fixed: 0,
        report: path,
        notes: scan_notes,
    });
}

phase("Fix");
log("Fixing " + to_fix.len().to_string() + " gap(s) in parallel worktrees");

let fix_jobs = [];
for g in to_fix {
    let fp = rails;
    fp += "LANE=fix. Apply ONE minimal surgical fix for this gap only. ";
    fp += "id=" + g.id + " file=" + g.file + " issue=" + g.issue + " priority=" + g.priority + ". ";
    fp += "Edit only files needed for this gap. Prefer adding/adjusting a unit test with the fix. ";
    fp += "Do NOT commit. Do NOT open full-nude gate. Do NOT generate images. ";
    fp += "Return changed=true/false, summary, files[], test_hint for which package to test.";
    // Shared workspace (not isolation_worktree): gaps should be different files;
    // fixes must land for continuous polish. Keep max_gaps small (default 2).
    fix_jobs.push(#{
        prompt: fp,
        label: "fix:" + g.id,
        capability_mode: "read-write",
        output_schema: fix_schema,
    });
}
let fixes = parallel(fix_jobs);

let fixed_count = 0;
let fix_summaries = [];
let test_packages = [];
for r in fixes {
    if r != () && r.success && r.output.changed == true {
        fixed_count += 1;
        if r.output.summary != () { fix_summaries.push(r.output.summary); }
        if r.output.test_hint != () { test_packages.push(r.output.test_hint); }
    }
}

phase("Verify");
let vp = rails;
vp += "VERIFY. In repo " + root + " run: ";
vp += "swift test --package-path Packages/ClosetCore ; ";
vp += "swift test --package-path Packages/ClosetModel ; ";
vp += "swift test --package-path Packages/ClosetUI . ";
vp += "Report core_ok/model_ok/ui_ok booleans from actual command exit status. ";
vp += "If a package was not needed and you still ran it, report real result. ";
vp += "summary one line; failures short.";
let ver = agent(vp, #{
    label: "verify:swift-test",
    capability_mode: "execute",
    output_schema: verify_schema,
});

let core_ok = false;
let model_ok = false;
let ui_ok = false;
let vsum = "verify failed";
let vfail = "";
if ver != () && ver.success {
    core_ok = ver.output.core_ok;
    model_ok = ver.output.model_ok;
    ui_ok = ver.output.ui_ok;
    if ver.output.summary != () { vsum = ver.output.summary; }
    if ver.output.failures != () { vfail = ver.output.failures; }
}

let report = "# cloth-polish-parallel\n\n";
report += "- root: " + root + "\n";
report += "- gaps_found: " + all_gaps.len().to_string() + "\n";
report += "- fixed_attempts: " + to_fix.len().to_string() + "\n";
report += "- changed: " + fixed_count.to_string() + "\n";
report += "- tests: core=" + core_ok.to_string() + " model=" + model_ok.to_string() + " ui=" + ui_ok.to_string() + "\n";
report += "- verify: " + vsum + "\n";
if vfail != "" { report += "- failures: " + vfail + "\n"; }
report += "\n## Fixes\n";
for s in fix_summaries { report += "- " + s + "\n"; }
report += "\n## Note\n";
report += "Fix agents shared main workspace (parallel, max_gaps capped). Diffs land in-repo uncommitted.\n";

let rpath = write_scratch_file("polish-report.md", report);
log(vsum);

complete(#{
    summary: "fixed=" + fixed_count.to_string() + " gaps=" + all_gaps.len().to_string() + " | " + vsum,
    gaps_found: all_gaps.len(),
    fixed: fixed_count,
    core_ok: core_ok,
    model_ok: model_ok,
    ui_ok: ui_ok,
    report: rpath,
});
