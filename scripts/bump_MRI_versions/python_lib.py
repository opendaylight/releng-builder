import pandas as pd

def find_highest_revision(revisions):
  # list to pandas DataFrame
  df = pd.DataFrame (revisions, columns = ['version'])
  # split pandas DataFrame by '.'
  df_splitted = df['version'].str.split('.',expand=True)
  # return filtered max versions (max by first column)
  df_max_by_0 = df_splitted.astype(int)[df_splitted[0].astype(int)==df_splitted[0].astype(int).max()]
  print(df_max_by_0)
  # try:
  #   df_max_by_1 = df_max_by_0.astype(int)[df_splitted[1].astype(int)==df_splitted[1].astype(int).max()]
  # except UserWarning:
  #   print("going trough UserWarning")
  #   df_max_by_1 = df_max_by_0.astype(int)[df_splitted[2].astype(int)==df_splitted[2].astype(int).max()]

  print(df_max_by_0)