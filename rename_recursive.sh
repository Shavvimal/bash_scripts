# I am using this bash command to recursively rename all files in a directory from `.md` to `.mdx`.
find . -name "*.md" | while read -r file; do mv "$file" "${file%.md}.mdx"; done
