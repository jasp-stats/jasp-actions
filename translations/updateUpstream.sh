#!/bin/bash

echo "Attempting to push any changed files."

git config user.name github-actions
git config user.email github-actions@github.com

echo "$(git pull --rebase)"
echo "Status after pull:"
echo "$(git status)"

git add "po" "inst/qml/translations" 
git add "*.po"
git add "*.pot"
git add "*.qm"
git add "*.mo"
git diff-index --quiet HEAD

if [ $? = 0 ] ; then
	echo "No translations files were updated, possibly only pushing a merged weblate PR ."
fi

# also print the commands for some nicer feedback
echo "$(git status)"
echo "$(git commit -m 'updated translation files')"
echo "$(git status)"
echo "$(git push --force-with-lease)"
echo "$(git status)"

if [ $? = 0 ] ; then
	echo "pushed directly to master."
	exit 0;
else
	echo "pushing failed!"
	exit 1;
fi
