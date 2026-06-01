require 'xcodeproj'

project_path = File.expand_path('~/DevTeam/projects/vocab-game/VocabGame.xcodeproj')
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'VocabGame_macOS' }

# Find the VocabGame group (where other source files live)
vocab_group = project.main_group.find_subpath('VocabGame', true)

files_to_add = {
  'Models/EggCharacter.swift' => 'Models',
  'Views/PetHouse/CharacterSelectView.swift' => 'Views/PetHouse',
}

files_to_add.each do |filename, group_path|
  full_path = File.expand_path("~/DevTeam/projects/vocab-game/VocabGame/#{filename}")
  next unless File.exist?(full_path)
  
  # Check if already in project
  existing = project.files.find { |pf| pf.real_path.to_s == full_path }
  if existing
    puts "  Skip (already in project): #{filename}"
    next
  end
  
  # Get or create the subgroup
  grp = vocab_group
  group_path.split('/').each do |part|
    grp = grp.find_subpath(part, true)
  end
  
  ref = grp.new_file(filename)
  target.source_build_phase.add_file_reference(ref)
  puts "  Added: #{filename} (group: #{group_path})"
end

project.save
puts "✅ Project saved"
