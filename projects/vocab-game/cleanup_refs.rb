require 'xcodeproj'

project_path = File.expand_path('~/DevTeam/projects/vocab-game/VocabGame.xcodeproj')
project = Xcodeproj::Project.open(project_path)

target = project.targets.find { |t| t.name == 'VocabGame_macOS' }

# Remove broken references (files with wrong path at project root)
broken_paths = ['Views/PetHouse/CharacterSelectView.swift', 'Models/EggCharacter.swift']

broken_paths.each do |bp|
  ref = project.files.find { |pf| pf.path == bp }
  if ref
    # Remove from build phase
    target.source_build_phase.files.each do |bf|
      if bf.file_ref == ref
        bf.remove_from_project
        break
      end
    end
    ref.remove_from_project
    puts "  Removed broken ref: #{bp}"
  end
end

project.save
puts "✅ Cleaned up"
