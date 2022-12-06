import pandas as pd

def find_highest_revision(revisions):
  # list to pandas DataFrame
  df = pd.DataFrame (revisions, columns = ['version'])
  # split pandas DataFrame by '.'
  df_splitted = df['version'].str.split('.',expand=True)
  # return filtered max versions (max by first column)
  return df_splitted.astype(int)[df_splitted[0].astype(int)==df_splitted[0].astype(int).max()]