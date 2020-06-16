# Reproducibility in Machine-Learning: Feasibility of automated Replication
As part of a seminar at the University of Passau I analysed code-guidelines for facilitating reproduction of machine-learning papers with code. 

## Gather data
If you want to reproduce the study, gathering data is not required.
1. In order to extensively retrieve github data, acquire an auth-token from
your github profile: 
`Top-right -> Settings -> Developer Setting -> Personal Access tokens`
or click [here](https://github.com/settings/tokens) and copy it into the `config.yaml`.
2. Run the `notebook.ipynb` in order to download the paper data from paperswithcode.com,
retrieve the github-repo-information and save it to a SQLite database.

## Run Analysis 
1. If you want to use the data from the paper, extract this [file](https://drive.google.com/file/d/1or4qpxcFE2y1yxlZRER1jtB7CveokAY_/view?usp=sharing) in the `/data` directory.
2. Run the `paper analysis.rmd` script to perform the guideline satisfactory analysis. The file is stored in `/scripts` directory.
