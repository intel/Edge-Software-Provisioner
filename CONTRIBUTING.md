# How to contribute

## Branching strategy
The common approach for this repo is, that the main developent branch is *main*. This branch should always be in a good state and the code from this branch should
always be in a state so that it could be released any time.
Releases will be done based on tags, only when needed we will create a separate branch for the release.

## Tagging
Each tag should have the format *vMAJOR.MINOR.PATCH*, e.g. v2.5.0  
If we create a release branch, then the branch name must not be equal to the tag name. Instead, we call the branch *vMAJOR.MINOR*, e.g. v2.5
On a release branch we will only do urgent bug fixes. These fixes must then be ported back to main development branch.

## Development branches
Each developer should create a separate development branch (based on latest main) and give it a meaningful name like feature/FEATURE_NAME, e.g feature/add_network
Development branches should be deleted after they are merged to the main branch.

## Merging to main
For merging the development branches to main we use pull requests.
The development branches might need a rebase on the main branch, this is highlighted on the pull request overview.
