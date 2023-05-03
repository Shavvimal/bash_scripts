# Print out a list of directories to be deleted:
find . -name 'node_modules' -type d -prune
# Delete node module directories recursively from the current working directory:
find . -name 'node_modules' -type d -prune -exec rm -rf '{}' +