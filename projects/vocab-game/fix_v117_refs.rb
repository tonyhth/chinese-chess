require 'xcodeproj'

project_path = File.expand_path('~/DevTeam/projects/vocab-game/VocabGame.xcodeproj')
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'VocabGame_macOS' }

# Clean up all broken refs for these files first
to_remove = []
project.files.each do |pf|
  if pf.path && (pf.path.include?('EggCharacter') || pf.path.include?('CharacterSelect'))
    # Check if real path exists
    real = pf.real_path.to_s
    unless File.exist?(real)
      to_remove << pf
    end
  end
end
to_remove.each do |ref|
  target.source_build_phase.files.each do |bf|
    if bf.file_ref == ref
      bf.remove_from_project
    end
  end
  ref.remove_from_project
  puts "  Cleaned: #{ref.path}"
end

# Now add correctly
# The VocabGame group is where source files live
vocab_group = project.main_group.find_subpath('VocabGame', false)
unless vocab_group
  puts "ERROR: Can't find VocabGame group"
  exit 1
end

# Find existing subgroups
models_group = vocab_group.groups.find { |g| g.display_name == 'Models' }
views_group = vocab_group.groups.find { |g| g.display_name == 'Views' }

unless models_group && views_group
  puts "ERROR: Can't find Models or Views group"
  puts "Available groups: #{vocab_group.groups.map(&:display_name).inspect}"
  exit 1
end

pethouse_group = views_group.groups.find { |g| g.display_name == 'PetHouse' }

# Add EggCharacter.swift to Models group
ec_ref = models_group.new_file('EggCharacter.swift')
target.source_build_phase.add_file_reference(ec_ref)
puts "  Added: EggCharacter.swift to Models"

# Add CharacterSelectView.swift to Views/PetHouse group
cs_ref = pethouse_group.new_file('CharacterSelectView.swift')
target.source_build_phase.add_file_reference(cs_ref)
puts "  Added: CharacterSelectView.swift to Views/PetHouse"

project.save
puts "✅ Project saved"
