require 'xcodeproj'

project_path = 'LOAD.xcodeproj'
target_name = 'LOAD'

project = Xcodeproj::Project.open(project_path)
target = project.targets.find { |t| t.name == target_name }

if target
  sources_phase = target.source_build_phase
  
  # Collect all Swift build files to remove
  swift_build_files = sources_phase.files.select do |build_file|
    file_ref = build_file.file_ref
    file_ref && file_ref.path.end_with?('.swift')
  end

  swift_build_files.each do |build_file|
    sources_phase.remove_build_file(build_file)
    puts "Removed build file for #{build_file.file_ref.path}"
    # Optionally remove the file reference from the project as well if it's no longer used anywhere else
    # file_ref = build_file.file_ref
    # project.files.delete(file_ref) if file_ref
  end

  # Remove all file references for .swift files from the main group as well
  # This helps clean up the project navigator if files were added directly to the root or other groups
  project.files.each do |file_ref|
    if file_ref.path.end_with?('.swift')
      file_ref.remove_from_project
      puts "Removed file reference for #{file_ref.path}"
    end
  end

  project.save
  puts "Successfully removed all Swift files from the Sources build phase and project references in #{project_path}."
else
  puts "Error: Target '#{target_name}' not found."
end