#!/usr/bin/env python3
"""Add untracked Swift files to Xcode project.pbxproj."""
import hashlib

PBXPROJ = "/Users/hth/DevTeam/projects/vocab-game/VocabGame.xcodeproj/project.pbxproj"

APP_FILES = [
    ("Achievement.swift", "VocabGame/Models/Achievement.swift", "Models"),
    ("AchievementEvent.swift", "VocabGame/Models/AchievementEvent.swift", "Models"),
    ("Food.swift", "VocabGame/Models/Food.swift", "Models"),
    ("PetDialogue.swift", "VocabGame/Models/PetDialogue.swift", "Models"),
    ("ThemeSkin.swift", "VocabGame/Models/ThemeSkin.swift", "Models"),
    ("EasterEggManager.swift", "VocabGame/Services/EasterEggManager.swift", "Services"),
    ("AchievementRepository.swift", "VocabGame/Repositories/AchievementRepository.swift", "Repositories"),
    ("WordRunnerViewModel.swift", "VocabGame/ViewModels/WordRunnerViewModel.swift", "ViewModels"),
    ("ComboText.swift", "VocabGame/Views/Components/ComboText.swift", "Components"),
    ("CustomTabBar.swift", "VocabGame/Views/Components/CustomTabBar.swift", "Components"),
    ("PetDialogueBubble.swift", "VocabGame/Views/Components/PetDialogueBubble.swift", "Components"),
    ("AchievementWallView.swift", "VocabGame/Views/Game/AchievementWallView.swift", "Game"),
    ("WordRunnerView.swift", "VocabGame/Views/Game/WordRunnerView.swift", "Game"),
]

TEST_FILES = [
    ("V116V2AuditTests.swift", "VocabGameTests/V116V2AuditTests.swift", "VocabGameTests"),
]

def gen_id(label):
    return hashlib.sha256(label.encode()).hexdigest()[:24].upper()

with open(PBXPROJ, 'r') as f:
    lines = f.readlines()

all_files = APP_FILES + TEST_FILES
file_data = []
for name, path, group in all_files:
    fr_id = gen_id(f"fr4_{name}")
    bf_id = gen_id(f"bf4_{name}")
    file_data.append((name, path, group, fr_id, bf_id))

# Find line indices
build_file_end = None
file_ref_end = None

for i, line in enumerate(lines):
    if '/* End PBXBuildFile section */' in line:
        build_file_end = i
    if '/* End PBXFileReference section */' in line:
        file_ref_end = i

# Find group closures: scan for lines like "path = Models;" and look back for ");"
group_close = {}
for i, line in enumerate(lines):
    stripped = line.strip()
    if stripped.startswith('path = ') and stripped.endswith(';'):
        gname = stripped[7:].rstrip(';').strip()
        # Find the previous ");" (children list close)
        for j in range(i - 1, max(i - 30, -1), -1):
            if lines[j].strip() == ');':
                group_close[gname] = j
                break

# Find Sources build phases
# Test phase ID: DC53C2A4A1BD74D691AC1A93
test_phase_id = 'DC53C2A4A1BD74D691AC1A93'
app_sources_close = None
test_sources_close = None

# Find the Sources phase IDs by scanning PBXSourcesBuildPhase entries
phase_ids = []
for i, line in enumerate(lines):
    if 'isa = PBXSourcesBuildPhase' in line:
        # Get the phase ID from the line before
        phase_ids.append(i)

# For each phase, determine if it's test or app by looking at its files
for phase_start in phase_ids:
    # Find the closing );
    for j in range(phase_start + 1, min(phase_start + 50, len(lines))):
        if lines[j].strip() == ');':
            # Check if this phase contains test files
            phase_content = ''.join(lines[phase_start:j+1])
            if 'MatchGameViewModelTests.swift' in phase_content:
                test_sources_close = j
            elif 'VocabGameApp.swift' in phase_content:
                app_sources_close = j
            break

print(f"build_file_end: {build_file_end}")
print(f"file_ref_end: {file_ref_end}")
print(f"app_sources_close: {app_sources_close}")
print(f"test_sources_close: {test_sources_close}")
print(f"Groups: {list(group_close.keys())}")

if not all([build_file_end, file_ref_end, app_sources_close, test_sources_close]):
    print("ERROR: Could not find all required anchors!")
    sys.exit(1)

# Prepare insertions: {line_idx: [lines_to_insert_after]}
insertions = {}

# 1. PBXBuildFile entries (insert before End marker = after line before End)
bf_lines = []
for name, path, group, fr_id, bf_id in file_data:
    bf_lines.append(f"\t\t{bf_id} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {fr_id} /* {name} */; }};\n")
insertions.setdefault(build_file_end - 1, []).extend(bf_lines)

# 2. PBXFileReference entries
fr_lines = []
for name, path, group, fr_id, bf_id in file_data:
    fr_lines.append(f"\t\t{fr_id} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; name = {name}; path = {path}; sourceTree = SOURCE_ROOT; }};\n")
insertions.setdefault(file_ref_end - 1, []).extend(fr_lines)

# 3. Group children
for name, path, group, fr_id, bf_id in file_data:
    if group in group_close:
        line = f"\t\t\t\t{fr_id} /* {name} */,\n"
        insertions.setdefault(group_close[group], []).append(line)

# 4. Sources build phases
for name, path, group, fr_id, bf_id in file_data:
    line = f"\t\t\t\t{bf_id} /* {name} in Sources */,\n"
    if group == "VocabGameTests":
        insertions.setdefault(test_sources_close, []).append(line)
    else:
        insertions.setdefault(app_sources_close, []).append(line)

# Apply in reverse order to preserve line numbers
for idx in sorted(insertions.keys(), reverse=True):
    for j, new_line in enumerate(insertions[idx]):
        lines.insert(idx + 1 + j, new_line)

with open(PBXPROJ, 'w') as f:
    f.writelines(lines)

print(f"\nDone! Added {len(file_data)} files to pbxproj.")
