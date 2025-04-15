#!/bin/bash

# Make all shell scripts in utils directory executable
echo "Setting executable permissions for all scripts..."
find utils -name "*.sh" -type f -exec chmod +x {} \;

# Make additional script types executable
find utils -name "*.py" -type f -exec chmod +x {} \;

echo "Done! All scripts should now be executable." 