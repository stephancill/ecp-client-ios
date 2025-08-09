#!/bin/zsh
#  ci_post_xcodebuild.sh
#  Dynamic content generation script for Xcode Cloud builds

echo "Starting dynamic content generation..."

if [[ -d "$CI_APP_STORE_SIGNED_APP_PATH" ]]; then
  TESTFLIGHT_DIR_PATH=../TestFlight
  echo "Creating TestFlight directory at: $TESTFLIGHT_DIR_PATH"
  mkdir -p $TESTFLIGHT_DIR_PATH
  
  # Generate What to Test notes from recent commits
  echo "Generating tester notes from recent commits..."
  git fetch --deepen 5
  
  # Create the main content with recent commits
  git log -5 --pretty=format:"• %s" >> $TESTFLIGHT_DIR_PATH/WhatToTest.en-US.txt
  
  echo "TestFlight notes generated successfully!"
  echo "Content preview:"
  cat $TESTFLIGHT_DIR_PATH/WhatToTest.en-US.txt
else
  echo "Not an App Store signed build - skipping TestFlight content generation"
fi

echo "Dynamic content generation completed!"