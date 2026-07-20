read_rds_input <- function(path) {
  obj <- if (grepl("^(https?|ftp)://", path)) {
    readRDS(url(path))
  } else {
    readRDS(path)
  }
  # readRDS() via a url() connection skips terra's serialization hook that
  # normally reconstructs a live SpatRaster/SpatVector on local reads, leaving
  # e.g. a raster as an inert PackedSpatRaster. terra::unwrap() fixes that and
  # is a harmless passthrough for any non-terra object (data.frame, sf, etc).
  terra::unwrap(obj)
}
