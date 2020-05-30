# Reproducibility on ML Papers
As part of a seminar at the University of Passau I analyse code-guidelines for facilitating reproduction of machine-learning papers with code. 

## Run
1. In order to extensively retrieve github data, acquire an auth-token from
your github profile: 
`Top-right -> Settings -> Developer Setting -> Personal Access tokens`
or click [here](https://github.com/settings/tokens) and copy it to the `config.yaml`.
2. Run the `notebook.ipynb` in order to download the paper data from paperswithcode.com,
retrieve the github-repo-information and save it to a SQLite database.
3. Run the `analyse_papers.R` script to perform the guideline satisfactory analysis.