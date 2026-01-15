require 'xcodeproj'

project_path = 'LOAD.xcodeproj'
target_name = 'LOAD'
old_file_name = 'Image+Color.swift'
new_file_name = 'Extensions.swift'

project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == target_name }

if target
  sources_phase = target.source_build_phase

  # Find and remove the old file reference
  old_file_ref = sources_phase.files_references.find { |f| f.path.end_with?(old_file_name) }
  if old_file_ref
    sources_phase.remove_file_reference(old_file_ref)
    puts "Removed reference to #{old_file_name}"
  end

  # Add the new file reference
  new_file_ref = project.new_file("LOAD/Utilities/#{new_file_name}")
  sources_phase.add_file_reference(new_file_ref)
  puts "Added reference to #{new_file_name}"

  project.save
else
  puts "Target not found"
end
