#!/bin/bash

echo -e "\033[1;94m🔧 Setting up MacPorts"
curl -LO https://raw.githubusercontent.com/GiovanniBussi/macports-ci/master/macports-ci
source ./macports-ci install

echo -e "\033[1;94m⬇️ Installing GitHub CLI"
sudo port install gh

echo -e "\033[1;94m😀 Authenticating GitHub CLI"
echo $TOKEN >> token.txt
gh auth login --with-token < token.txt
gh auth status

echo -e "\033[1;94m🔍 Determining current outdated version"
CURRENT=$(port info --version $NAME | sed 's/[A-Za-z: ]*//g')  # Remove letters, colon and space
echo "Current version number is $CURRENT!"

echo -e "\033[1;94m🏷️ Determining new version from tag"
# We want to keep the dots, but remove all letters
TAG=$(echo $TAG | sed 's/[A-Za-z]*//g')
echo "New version number is $TAG!"

echo -e "\033[1;94m📒 Determining Category"
CATEGORY=$(port info --category $NAME)
CATEGORY_LIST=($CATEGORY)
CATEGORY=${CATEGORY_LIST[1]}  # Only take the first category
CATEGORY=$(echo "$CATEGORY" | tr "," "\n")  # Replace commas with line breaks
echo "Category is $CATEGORY!"

echo -e "\033[1;94m⬇️ Cloning MacPorts Repo"
gh repo fork $REPO --clone=true --remote=true
# Name of the cloned folder
CLONE=$(echo $REPO | awk -F'/' '{print $2}')

echo -e "\033[1;94m📁 Creating local Portfile Repo"
mkdir -p ports/$CATEGORY/$NAME
# Copy Portfile to the local repo
cp $CLONE/$CATEGORY/$NAME/Portfile ports/$CATEGORY/$NAME/Portfile
source macports-ci localports ports

echo -e "\033[1;94m⏫ Bumping Version"
# Replaces first instance of old version with new version
sed -i '' "1,/$CURRENT/ s/$CURRENT/$TAG/" ports/$CATEGORY/$NAME/Portfile
sudo port bump $NAME

echo -e "\033[1;94m📨 Sending PR"

# Finds public emails and takes the first one
EMAIL=$(gh api /user/public_emails | jq --raw-output '.[0] | .email')

# Git credentials
# echo "https://$USER:$TOKEN@github.com" > ~/.git-credentials
git config user.email $EMAIL
git config user.name $USER
git config user.password $TOKEN

cd $CLONE
git checkout -b $NAME
# Copy changes back to main repo
cp ../ports/$CATEGORY/$NAME/Portfile $CATEGORY/$NAME/Portfile
git add $CATEGORY/$NAME/Portfile
git commit -m "$NAME: update to $TAG"
# git push --set-upstream origin $NAME
gh pr create --title "$NAME: update to $TAG" --body "Created with [`action-macports-bump`](https://github.com/harens/action-macports-bump)" --base=master --head=$NAME
