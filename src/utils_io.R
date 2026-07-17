read_rds_input <- function(path) {
  if (grepl("^(https?|ftp)://", path)) {
    readRDS(url(path))
  } else {
    readRDS(path)
  }
}
