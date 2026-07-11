#!/usr/bin/env Rscript

################################################################################
# MODULE: Create two evaluation datasets respectively based on 
# weighted refinement compared with census grid 2021 data and on
# simple refinement also compared with census grid 2021. 
#
################################################################################

# --- 1. DEPENDENCIES ---
library(sf)
library(dplyr)
library(ggplot2)
library(plotly)
library(htmlwidgets)
#library(htmltools)
library(classInt)
library(terra)
library(tmap)

# --- 2. GLOBAL SETTINGS ---
options(scipen = 100, digits = 4)

# Prefer preferred_col; fall back to fallback_col if preferred_col has no
# usable (positive) values for this catchment — e.g. Eurostat's 2021 census
# grid doesn't cover the UK, but 2018 does.
resolve_census_grid_value_col <- function(census_grid, preferred_col = "TOT_P_2021", fallback_col = "TOT_P_2018") {
  col_has_usable_data <- function(col) {
    col %in% names(census_grid) &&
      any(!is.na(census_grid[[col]]) & census_grid[[col]] > 0)
  }
  if (!col_has_usable_data(preferred_col) && col_has_usable_data(fallback_col)) {
    message(sprintf(
      "Note: '%s' has no usable population data for this catchment; falling back to '%s'.",
      preferred_col, fallback_col
    ))
    return(fallback_col)
  }
  preferred_col
}

# --- 3. FUNCTION DEFINITIONS (Original Code) ---
################################################################################
# HELPING FUNCTION
get_corine_colors_as_hex <- function(clc_legend,
                                     df_input,
                                     cor_code_raster_columnname) { 
  
  # create new column with hex colors
  clc_legend <- clc_legend %>%
    dplyr::mutate(hex_color = rgb(Red, 
                                  Green, 
                                  Blue))
  
  # ensure it is numeric
  df_input[[cor_code_raster_columnname]] <- as.numeric(df_input[[cor_code_raster_columnname]])
  
  # add hex colors to input table 
  df_input <- dplyr::left_join(df_input, 
                               clc_legend[, c(cor_code_raster_columnname, 
                                              "hex_color")], 
                               by = cor_code_raster_columnname)
  
  # check that both clc_legend and df_input has cor_code_raster_columnname!
  
  # return
  return(df_input)
}   

################################################################################
# VISUALISATION 1
#' Generate and Save Input Weight Histogram (Interactive HTML)
#'
#' Creates an interactive stacked bar chart showing the distribution
#' of input weights across CORINE land cover classes using official
#' CORINE colours.
#'
#' @param weight_table_final data.frame: Weight table containing at least
#'   columns 'percent' and 'LABEL'.
#' @param clc_legend data.frame: CORINE legend used to retrieve official colours.
#' @param output_path character: Path where the HTML file will be saved.
#'
#' @return invisible(NULL). Writes the HTML widget to disk.
save_weight_histogram <- function(weight_table_final,
                                  clc_legend,
                                  cor_code_raster_columnname,
                                  output_path) {

  required_cols <- c("percent", "LABEL")
  missing_cols <- setdiff(required_cols, names(weight_table_final))
  if (length(missing_cols) > 0) {
    stop(
      paste(
        "Missing required column(s):",
        paste(missing_cols, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  
  if (nrow(weight_table_final) == 0) {
    warning("Weight table is empty. Histogram not generated.")
    return(invisible(NULL))
  }
  
  # sum weights 
  weight_table_final <- weight_table_final %>%
    dplyr::mutate(
      percent100 = percent / sum(percent) * 100
    )
  
  weight_table_final <- get_corine_colors_as_hex(
    clc_legend = clc_legend,
    df_input = weight_table_final,
    cor_code_raster_columnname = cor_code_raster_columnname
  )
  
  # create histogram over weight distribution among CORINE classes using official colors
  p <- ggplot2::ggplot(
    weight_table_final,
    ggplot2::aes(
      x = "Input weights", # x "" should be the same for all categories so they are stacked
      y = percent100, # column to plot and determine height of bar parts
      fill = LABEL, # fill color to be overwritten later
      text = paste0(
        "<b>", LABEL, "</b><br>",
        "Weight: ", round(percent, 2), "%<br>",
        "Normalised: ", round(percent100, 2), "%"
      )
    )
  ) +
    ggplot2::geom_col(width = 0.7) + # width of bars (0.6 + ggplot2::geom_text)
    ggplot2::scale_fill_manual(
      values = stats::setNames(
        weight_table_final$hex_color,
        weight_table_final$LABEL
      )
    ) +
    ggplot2::scale_y_continuous(
      labels = function(x) paste0(round(x, 1), "%") # y axis should be formatted as percentage
    ) +
    ggplot2::labs(
      title = "Input weights", # main plot title
      x = NULL, # no x axis title
      y = "Percentage of input weight sum", # y axis title
      fill = "CORINE category" # legend title
    ) +
    ggplot2::theme_minimal() + # simple plot style with no background
    ggplot2::theme(
      axis.text.x = ggplot2::element_blank(), # x axis labels are empty anyway due to single bar
      axis.ticks.x = ggplot2::element_blank() # remove x axis ticks
    )
  
  # convert to interactive plotly
  p_widget <- plotly::ggplotly(
    p,
    tooltip = "text"
  )
  
  # saving histogram as self-contained HTML
  htmlwidgets::saveWidget(
    widget = p_widget,
    file = output_path,
    selfcontained = TRUE
  )
  invisible(NULL)
}

################################################################################
# VISUALISATION 2
save_cor_distribution_in_lau_histogram <- function(cell_counts,
                                                   cor_code_raster_columnname,
                                                   clc_legend, 
                                                   output_path)
  { 
  required_cols <- c("LAU_ID", "corine")
  missing_cols <- setdiff(required_cols, names(cell_counts))
  if (length(missing_cols) > 0) {
    stop(
      paste(
        "Missing required column(s):",
        paste(missing_cols, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  
  numb_of_lau <- length(unique(cell_counts$LAU_ID))
  
  # Count how many unique NUTS each CODE_18 appears in
  code_counts_summary <- cell_counts %>%
    dplyr::group_by(corine) %>%
    dplyr::summarise(
      n_LAU = n_distinct(LAU_ID),
      .groups = "drop"
    ) %>%
    dplyr::arrange(desc(n_LAU), corine)
  
  # as integer
  code_counts_summary$n_LAU <- as.integer(code_counts_summary$n_LAU)
  
  # call corine ID column right name for hex function to work
  # Example: rename "n_cells" to "num_cells"
  names(code_counts_summary)[names(code_counts_summary) == "corine"] <- cor_code_raster_columnname
  code_counts_summary[[cor_code_raster_columnname]] <- as.numeric(code_counts_summary[[cor_code_raster_columnname]])
  # get color codes and add hex colors to area_by_class table
  code_counts_summary <- get_corine_colors_as_hex(clc_legend = clc_legend,
                                                  df_input = code_counts_summary,
                                                  cor_code_raster_columnname = cor_code_raster_columnname)

  # Convert CODE_18 to factor ordered by descending n_LAU
  code_counts_summary <- code_counts_summary %>%
    dplyr::mutate(
      "{cor_code_raster_columnname}" := factor(
        .data[[cor_code_raster_columnname]],
        levels = .data[[cor_code_raster_columnname]][
          order(-n_LAU, .data[[cor_code_raster_columnname]])
        ]
      )
    )
  
  # Plot histogram
  p_h <- ggplot2::ggplot(code_counts_summary, 
                         ggplot2::aes(x = .data[[cor_code_raster_columnname]], 
                                      y = n_LAU, 
                                      fill = hex_color)) +
    ggplot2::geom_col() +
    ggplot2::coord_flip() +   # horizontal bars for readability
    ggplot2::scale_fill_identity() +  # use hex colors directly
    ggplot2::scale_y_continuous(
      breaks = scales::pretty_breaks(),       # automatic breaks
      labels = function(x) as.integer(x)      # integer labels only
    ) +
    ggplot2::labs(
      x = "CORINE class code",
      y = "Number of LAU",
      title = paste0("Number out of ", 
                     numb_of_lau, 
                     " LAU containing each CORINE class")) +
    ggplot2::theme_minimal() +
    ggplot2::theme(plot.title = ggplot2::element_text(hjust = 0.5))
  
  # Convert to interactive plotly object
  p_plotly <- plotly::ggplotly(p_h, 
                               tooltip = c("x", "y"))
  
  # Save as HTML
  htmlwidgets::saveWidget(
    widget = p_plotly,
    file = output_path,
    selfcontained = TRUE
  )
}  

################################################################################
# HELPING FUNCTION
get_censusgrid_labels <- function(censusgrid,
                                  census_grid_value_col = "TOT_P_2021",
                                  max_classes = 8)
{
  
  x <- as.integer(censusgrid[[census_grid_value_col]])
  
  # remove invalid values
  x <- x[is.finite(x)]
  x <- x[x > 0]
  
  if (length(x) == 0) {
    message("No valid positive values found")
    return(NULL)
  }
  
  # check variation
  ux <- unique(x)
  if (length(ux) < 2) {
    message("No variation in values")
    return(c(min(x), max(x)))
  }
  
  # decide number of classes dynamically
  n_classes <- min(max_classes, length(unique(x)))
  
  # ensure at least 2 classes
  n_classes <- max(2, n_classes)
  
  # quantile breaks with safety wrapper
  class_intervals <- tryCatch(
    classInt::classIntervals(x,
                             n = n_classes,
                             style = "quantile"),
    error = function(e) {
      message("classIntervals failed, falling back to simple quantiles")
      return(NULL)
    }
  )
  
  # fallback if quantile method fails
  if (is.null(class_intervals)) {
    return(unique(stats::quantile(x, probs = seq(0, 1, length.out = n_classes))))
  }
  
  brks <- class_intervals$brks
  
  # remove duplicates (important when many tied values exist)
  brks <- unique(brks)
  
  # ensure still valid
  if (length(brks) < 2) {
    return(c(min(x), max(x)))
  }
  
  #print("brks are: ")
  #print(brks)
  
  return(brks)
}

################################################################################
# VISUALISATION 3
save_map_censusgrid_observed <- function(
    census_grid_eval,
    class_intervals_censusgrid,
    catchment = NULL,
    output_path,
    census_grid_value_col = "TOT_P_2021"
) {
  
  # Ensure numeric
  census_grid_eval[[census_grid_value_col]] <-
    as.numeric(as.character(census_grid_eval[[census_grid_value_col]]))
  
  # Clean breaks
  class_intervals_censusgrid <-
    as.numeric(as.character(class_intervals_censusgrid))
  
  class_intervals_censusgrid <-
    sort(unique(class_intervals_censusgrid))
  
  class_intervals_censusgrid <-
    class_intervals_censusgrid[!is.na(class_intervals_censusgrid)]
  
  if (length(class_intervals_censusgrid) < 2) {
    stop("class_intervals_censusgrid must contain at least two break values.")
  }
  
  # Remove empty geometries
  census_grid_eval <-
    census_grid_eval[!sf::st_is_empty(census_grid_eval), ]
  
  # Transform to WGS84
  census_grid_eval_ll <- sf::st_transform(census_grid_eval, 4326)
  
  catchment_ll <- NULL
  if (!is.null(catchment)) {
    catchment_ll <- sf::st_transform(catchment, 4326)
  }
  
  # Number of intervals
  n_classes <- length(class_intervals_censusgrid) - 1
  
  # Colour palette
  palette <- colorRampPalette(
    RColorBrewer::brewer.pal(9, "YlOrRd")
  )(n_classes)
  
  # Interactive mode
  tmap_mode("view")
  
  # Main map
  map_main <-
    tm_shape(census_grid_eval_ll) +
    tm_polygons(
      fill = census_grid_value_col,
      fill.scale = tm_scale_intervals(
        breaks = class_intervals_censusgrid,
        values = palette
      ),
      fill_alpha = 0.7,
      col = "grey40",
      lwd = 0.2,
      popup.vars = c(
        "Population" = census_grid_value_col
      ),
      fill.legend = tm_legend(
        title = "Population"
      )
    ) +
    tm_basemap("CartoDB.Positron")
  
  # Catchment boundary
  if (!is.null(catchment_ll)) {
    map_main <-
      map_main +
      tm_shape(catchment_ll) +
      tm_borders(
        col = "blue",
        lwd = 2
      )
  }
  
  # Layout
  map_main <-
    map_main +
    tm_title("Census grid 2021") +
    tm_layout(
      legend.outside = TRUE,
      legend.outside.position = "right"
    ) +
    tm_compass(position = c("right", "bottom")) +
    tm_scalebar(position = c("left", "bottom"))
  
  # Save leaflet widget
  htmlwidgets::saveWidget(
    widget = tmap::tmap_leaflet(map_main),
    file = output_path,
    selfcontained = TRUE
  )
  
  invisible(map_main)
}

################################################################################
# VISUALISATION 4-5
save_map_lau_observed <- function(
    lau_in_catchment,
    lau_value_col,
    lau_area_col = "AREA_KM2",
    pop_year,
    catchment = NULL,
    output_path
) {
  
  # Population density
  lau_in_catchment$pop_dens_1km2 <-
    lau_in_catchment[[lau_value_col]] /
    lau_in_catchment[[lau_area_col]]
  
  observed_values <- lau_in_catchment$pop_dens_1km2
  observed_values <- observed_values[is.finite(observed_values)]
  observed_values_no_zero <- observed_values[observed_values > 0]
  
  if (length(unique(observed_values_no_zero)) < 2) {
    message("No variation in density values")
    return(invisible(NULL))
  }
  
  # Quantile breaks
  class_intervals <- classInt::classIntervals(
    observed_values_no_zero,
    n = 8,
    style = "quantile"
  )
  
  breaks_clean <- sort(unique(class_intervals$brks))
  
  if (length(breaks_clean) < 2) {
    message("Insufficient unique class breaks")
    return(invisible(NULL))
  }
  
  # Ensure all values are covered
  breaks_clean[length(breaks_clean)] <- Inf
  
  n_classes <- length(breaks_clean) - 1
  
  # Palette
  final_colors <- colorRampPalette(
    RColorBrewer::brewer.pal(9, "YlOrRd")
  )(n_classes)
  
  # Remove empty geometries
  lau_in_catchment <-
    lau_in_catchment[!sf::st_is_empty(lau_in_catchment), ]
  
  # Transform to WGS84
  lau_ll <- sf::st_transform(lau_in_catchment, 4326)
  
  catchment_ll <- NULL
  if (!is.null(catchment)) {
    catchment_ll <- sf::st_transform(catchment, 4326)
  }
  
  # Interactive mode
  tmap_mode("view")
  
  # Main map
  map_main <-
    tm_shape(lau_ll) +
    tm_polygons(
      fill = "pop_dens_1km2",
      fill.scale = tm_scale_intervals(
        breaks = breaks_clean,
        values = final_colors
      ),
      fill_alpha = 0.7,
      col = "grey40",
      lwd = 0.2,
      popup.vars = c(
        "LAU ID" = "LAU_ID",
        "Population density" = "pop_dens_1km2"
      ),
      fill.legend = tm_legend(
        title = paste0(
          "Population density\n(persons/km², ",
          pop_year,
          ")"
        )
      )
    ) +
    tm_basemap("CartoDB.Positron")
  
  # Catchment outline
  if (!is.null(catchment_ll)) {
    map_main <-
      map_main +
      tm_shape(catchment_ll) +
      tm_borders(
        col = "blue",
        lwd = 2
      )
  }
  
  # Layout
  map_main <-
    map_main +
    tm_title(
      paste0(
        "Population density LAU (",
        pop_year,
        ")"
      )
    ) +
    tm_layout(
      legend.outside = TRUE,
      legend.outside.position = "right"
    ) +
    tm_compass(position = c("right", "bottom")) +
    tm_scalebar(position = c("left", "bottom"))
  
  # Save interactive leaflet map
  htmlwidgets::saveWidget(
    widget = tmap::tmap_leaflet(map_main),
    file = output_path,
    selfcontained = TRUE
  )
  
  invisible(map_main)
}

################################################################################
# VISUALISATION 6-7
save_map_clc_observed <- function(cor_rast_geom,
                                  clc_legend,
                                  cor_name_raster_columnname,
                                  cor_code_raster_columnname,
                                  catchment,
                                  textstring,
                                  output_path) {
  
  # Shorten long labels
  clc_legend[[cor_name_raster_columnname]] <- ifelse(
    nchar(clc_legend[[cor_name_raster_columnname]]) > 35,
    paste0(substr(clc_legend[[cor_name_raster_columnname]], 1, 35), "."),
    clc_legend[[cor_name_raster_columnname]]
  )
  
  # Ensure categorical raster (robust terra method)
  cor_rast_geom <- terra::as.factor(cor_rast_geom)
  
  levels(cor_rast_geom) <- list(
    clc_legend[, c(
      cor_code_raster_columnname,
      cor_name_raster_columnname
    )]
  )
  
  cor_rast_geom <- terra::droplevels(cor_rast_geom)

  # Build palette (named by class values)
  cols <- rgb(
    clc_legend$Red,
    clc_legend$Green,
    clc_legend$Blue
  )
  
  names(cols) <- clc_legend[[cor_name_raster_columnname]]
  
  # Reproject for web
  cor_ll <- terra::project(cor_rast_geom, "EPSG:4326", method = "near")
  
  catchment_ll <- NULL
  if (!is.null(catchment)) {
    catchment_ll <- sf::st_transform(catchment, 4326)
  }
  
  # tmap v4 mode
  tmap_mode("view")
  
  # Main map (tmap v4 syntax)
  map_main <- tm_shape(cor_ll) +
    tm_raster(
      col.scale = tm_scale(values = cols),
      col_alpha = 0.8,
      col.legend = tm_legend(
        title = paste0(textstring, " CLC classes")
        )
      ) +
    tm_basemap("CartoDB.Positron")

  # Catchment overlay
  if (!is.null(catchment_ll)) {
    map_main <- map_main +
      tm_shape(catchment_ll) +
      tm_borders(col = "blue", lwd = 2)
  }
  
  # Layout + extras (v4 clean separation)
  map_main <- map_main +
    tm_title(paste0(textstring, " CLC Land Cover")) +
    tm_layout(
      legend.outside = TRUE,
      legend.outside.position = "right"
    ) +
    tm_compass(position = c("right", "bottom")) +
    tm_scalebar(position = c("left", "bottom"))
  
  # Save interactive map
  htmlwidgets::saveWidget(
    widget = tmap::tmap_leaflet(map_main),
    file = output_path,
    selfcontained = TRUE
  )
  
  invisible(map_main)
}

################################################################################
# VISUALISATION 8
save_map_pop_estimated <- function(est_pop_raster, 
                                   catchment,
                                   pop_year,
                                   output_path)
{ 
  if (names(est_pop_raster) != "pop_est") {
    stop(
      paste0(
        "Invalid raster name: ",
        names(est_pop_raster),
        ". Expected 'pop_est'."
      ),
      call. = FALSE
    )
  }
    
  # Extract values
  observed_values <- terra::values(est_pop_raster)[, 1]
    
  observed_values <- observed_values[
    is.finite(observed_values) &
      observed_values > 0
  ]
    
  if (length(observed_values) < 2) {
    warning("Insufficient variation in raster values.")
    return(invisible(NULL))
  }
  
  # Create classes
  class_intervals <- classInt::classIntervals(
    observed_values,
    n = min(8, length(unique(observed_values))),
    style = "quantile"
  )
    
  breaks_clean <- sort(unique(class_intervals$brks))

  if (length(breaks_clean) < 2) {
    warning("Could not create class breaks.")
    return(invisible(NULL))
  }

  # Extend the top break to Inf — reprojecting the raster for display
  # (terra::project() below) can nudge the true maximum a hair above its
  # original value via float32 drift in GDAL's warp, which would otherwise
  # push those cells outside the color scale and render them as NA/transparent.
  # The true max is kept only for the legend label, so it still reads e.g.
  # "6.8 - 16.6" instead of "6.8 - Inf".
  true_max <- max(breaks_clean)
  breaks_clean[length(breaks_clean)] <- Inf

  n_classes <- length(breaks_clean) - 1
  
  final_colors <- RColorBrewer::brewer.pal(
    max(3, min(9, n_classes)),
    "YlOrRd"
  )
    
  # Number of populated cells
  numb_of_100m2_cells <- sum(
    !is.na(terra::values(est_pop_raster))
  )
  
  # Reproject only for display
  est_pop_ll <- terra::project(
    est_pop_raster,
    "EPSG:4326",
    method = "near"
  )
    
  catchment_ll <- NULL
  if (!is.null(catchment)) {
    catchment_ll <- sf::st_transform(
      catchment,
      4326
    )
  }
    
  # Leaflet palette
  pal <- leaflet::colorBin(
    palette = final_colors,
    domain = observed_values,
    bins = breaks_clean,
    na.color = "transparent"
  )
    
  # Build map
  map_widget <- leaflet::leaflet() |>
    leaflet::addProviderTiles(
      leaflet::providers$CartoDB.Positron
    ) |>
    leaflet::addRasterImage(
      est_pop_ll,
      colors = pal,
      opacity = 1,
      project = FALSE
    )
    
  # Catchment outline
  if (!is.null(catchment_ll)) {
    map_widget <- map_widget |>
      leaflet::addPolygons(
        data = catchment_ll,
        color = "blue",
        weight = 2,
        fill = FALSE
      )
  }
    
  # Legend
  map_widget <- map_widget |>
    leaflet::addLegend(
      pal = pal,
      values = observed_values,
      title = "People / 100 m²",
      opacity = 1,
      position = "bottomright",
      labFormat = function(type, cuts, p) {
        cuts[is.infinite(cuts)] <- true_max
        paste(round(cuts[-length(cuts)], 1), round(cuts[-1], 1), sep = " - ")
      }
    )
    
  # Title
  map_widget <- map_widget |>
    leaflet::addControl(
      html = paste0(
        "<b>Est. ",
        pop_year,
        " population in ",
        format(numb_of_100m2_cells, big.mark = ","),
        " cells</b>"
      ),
      position = "topleft"
    )
    
  # Save HTML
  htmlwidgets::saveWidget(
    widget = map_widget,
    file = output_path,
    selfcontained = TRUE
  )
  invisible(map_widget)
}

################################################################################
# VISUALISATION 9
save_map_pop_errors_at_censusgrid <- function(
    census_grid_eval,
    catchment,
    pop_reference_year = "2021",
    census_grid_value_col = "TOT_P_2021",
    output_path
) {
  
  if (!"dif1" %in% names(census_grid_eval)) {
    stop("Column 'dif1' is missing.", call. = FALSE)
  }
  
  observed_values <- census_grid_eval$dif1
  
  if (length(observed_values) == 0) {
    message("No valid values")
    return(NULL)
  }
  
  # BREAKS (numeric classes)
  min_val <- min(observed_values, na.rm = TRUE)
  max_val <- max(observed_values, na.rm = TRUE)
  
  range_val <- max_val - min_val
  raw_step <- range_val / 10
  
  nice_step <- function(x) {
    base <- 10^floor(log10(x))
    candidates <- c(1, 2, 5, 10) * base
    candidates[which.min(abs(candidates - x))]
  }
  
  step <- nice_step(raw_step)
  
  breaks <- seq(
    floor(min_val / step) * step,
    ceiling(max_val / step) * step,
    by = step
  )
  
  # SPECIAL CLASS SPLIT
  idx_special <-
    census_grid_eval[[census_grid_value_col]] > 0 &
    (
      !is.finite(census_grid_eval$dif1) |
        census_grid_eval$pop_est_cell1 == 0
    )
  
  special_sf <- census_grid_eval[idx_special, ]
  normal_sf  <- census_grid_eval[!idx_special, ]
  
  normal_sf$dif_plot <- normal_sf$dif1
  
  # NORMAL PALETTE
  pal_normal <- leaflet::colorBin(
    palette = c(
      "darkred", "red", "#deebf7", "#B2DDFC",
      "#9ecae1", "#6baed6", "#2171b5",
      "#084594", "#8734ba", "#5e1989", "#170324"
    ),
    domain = normal_sf$dif_plot,
    bins = breaks,
    na.color = "#808080"
  )
  
  # SPECIAL CLASS
  special_sf$group <- "False negatives (pop > 0)"

  pal_special <- leaflet::colorFactor(
    palette = "yellow",
    levels = "False negatives (pop > 0)"
  )
  
  # PROJECT
  normal_ll  <- sf::st_transform(normal_sf, 4326)
  special_ll <- sf::st_transform(special_sf, 4326)
  
  catchment_ll <- NULL
  if (!is.null(catchment)) {
    catchment_ll <- sf::st_transform(catchment, 4326)
  }
  
  # TOOLTIP
  normal_ll$label_html <- lapply(
    paste0(
      "<strong>Observed:</strong> ", normal_ll[[census_grid_value_col]], "<br>",
      "<strong>Estimated:</strong> ", normal_ll$pop_est_cell1, "<br>",
      "<strong>Difference:</strong> ", round(normal_ll$dif1, 2)
    ),
    htmltools::HTML
  )

  special_ll$label_html <- lapply(
    paste0(
      "<strong>False negatives (pop > 0)</strong><br>",
      "<strong>Observed:</strong> ", special_ll[[census_grid_value_col]]
    ),
    htmltools::HTML
  )
  
  # MAP
  map_widget <- leaflet::leaflet() |>
    leaflet::addProviderTiles(leaflet::providers$CartoDB.Positron)
  
  # normal polygons
  map_widget <- map_widget |>
    leaflet::addPolygons(
      data = normal_ll,
      fillColor = ~pal_normal(dif_plot),
      fillOpacity = 0.7,
      color = NA,
      weight = 0,
      label = ~label_html
    )
  
  # special polygons (yellow)
  map_widget <- map_widget |>
    leaflet::addPolygons(
      data = special_ll,
      fillColor = ~pal_special(group),
      fillOpacity = 0.9,
      color = NA,
      weight = 0,
      label = ~label_html
    )
  
  # catchment
  if (!is.null(catchment_ll)) {
    map_widget <- map_widget |>
      leaflet::addPolygons(
        data = catchment_ll,
        fill = FALSE,
        color = "blue",
        weight = 1
      )
  }
  
  # LEGEND 
  # get numeric colors that match bins
  bin_centers <- breaks[-length(breaks)] + diff(breaks) / 2
  
  numeric_colors <- pal_normal(bin_centers)
  
  numeric_labels <- paste0(
    format(head(breaks, -1), scientific = FALSE),
    " – ",
    format(tail(breaks, -1), scientific = FALSE)
  )
  
  map_widget <- map_widget |>
    leaflet::addLegend(
      colors = c("yellow", numeric_colors),
      labels = c(
        "False negatives (pop > 0)",
        numeric_labels
      ),
      title = paste0("Population difference (", pop_reference_year, ")"),
      position = "bottomright"
    )
  
  # SAVE
  htmlwidgets::saveWidget(
    widget = map_widget,
    file = output_path,
    selfcontained = TRUE
  )
  
  invisible(map_widget)
}

################################################################################
# VISUALISATION 10
save_map_pop_BinaryPercErrors_at_censusgrid <- function(
    census_grid_eval,
    catchment,
    pop_reference_year = "2021",
    thresholdval,
    census_grid_value_col = "TOT_P_2021",
    thresholdvalfortruth,
    output_path
) {
  
  required_cols <- c("dif_perc1", "pop_est_cell1", census_grid_value_col)
  
  missing_cols <- setdiff(required_cols, names(census_grid_eval))
  if (length(missing_cols) > 0) {
    stop(
      paste("Missing required column(s):", paste(missing_cols, collapse = ", ")),
      call. = FALSE
    )
  }
  
  # SPECIAL + NORMAL SPLIT
  idx_special <-
    census_grid_eval$dif_perc1 == 999 |
    (
      census_grid_eval$dif_perc1 == 100 &
        census_grid_eval[[census_grid_value_col]] > thresholdvalfortruth
    )
  
  special_sf <- census_grid_eval[idx_special, ]
  normal_sf  <- census_grid_eval[!idx_special, ]
  
  # NORMAL VALUES FOR BREAKS
  idx_perc1 <- (
    normal_sf$pop_est_cell1 != 0 &
      !is.na(normal_sf$pop_est_cell1) &
      normal_sf$dif_perc1 != 999 &
      normal_sf$dif_perc1 != 100
  )
  
  observed_values <- normal_sf$dif_perc1[idx_perc1]
  observed_values <- observed_values[is.finite(observed_values)]
  
  if (length(observed_values) == 0) {
    message("No valid values")
    return(invisible(NULL))
  }
  
  # BREAKS
  max_val <- max(observed_values, na.rm = TRUE)
  if (!is.finite(max_val)) max_val <- thresholdval
  
  rounded_breaks <- sort(unique(c(0, thresholdval, max_val)))
  
  if (length(rounded_breaks) < 2) {
    rounded_breaks <- c(0, thresholdval)
  }
  
  labels <- paste0(
    rounded_breaks[-length(rounded_breaks)],
    "–",
    rounded_breaks[-1]
  )
  
  # NORMAL PALETTE
  normal_palette <- colorRampPalette(
    c("#2CF003", "darkgreen")
  )(length(rounded_breaks) - 1)
  
  pal_normal <- leaflet::colorBin(
    palette = normal_palette,
    domain = normal_sf$dif_perc1,
    bins = rounded_breaks,
    na.color = "transparent"
  )
  
  # SPECIAL CLASS LABELS
  special_sf$special_class <- NA_character_
  
  special_sf$special_class[
    special_sf$dif_perc1 == 999
  ] <- "False positives"

  special_sf$special_class[
    special_sf$dif_perc1 == 100 &
      special_sf[[census_grid_value_col]] > thresholdvalfortruth
  ] <- paste0(
    "False negatives (obs pop > ",
    thresholdvalfortruth,
    ")"
  )

  # remove any leftovers
  special_sf <- special_sf[!is.na(special_sf$special_class), ]

  pal_special <- leaflet::colorFactor(
    palette = c("red", "#F7E3B1"),
    levels = c(
      "False positives",
      paste0("False negatives (obs pop > ", thresholdvalfortruth, ")")
    )
  )
  
  # PROJECT TO WGS84
  normal_ll  <- sf::st_transform(normal_sf, 4326)
  special_ll <- sf::st_transform(special_sf, 4326)
  
  catchment_ll <- NULL
  if (!is.null(catchment)) {
    catchment_ll <- sf::st_transform(catchment, 4326)
  }
  
  # TOOLTIP
  normal_ll$label_html <- lapply(
    paste0(
      "<strong>Observed:</strong> ", normal_ll[[census_grid_value_col]], "<br>",
      "<strong>Estimated:</strong> ", normal_ll$pop_est_cell1, "<br>",
      "<strong>Error (%):</strong> ", round(normal_ll$dif_perc1, 2)
    ),
    htmltools::HTML
  )
  
  special_ll$label_html <- lapply(
    paste0(
      "<strong>Special case:</strong> ", special_ll$special_class, "<br>",
      "<strong>Observed:</strong> ", special_ll[[census_grid_value_col]]
    ),
    htmltools::HTML
  )
  
  # MAP
  map_widget <- leaflet::leaflet() |>
    leaflet::addProviderTiles(leaflet::providers$CartoDB.Positron)
  
  # NORMAL LAYER
  map_widget <- map_widget |>
    leaflet::addPolygons(
      data = normal_ll,
      fillColor = ~pal_normal(dif_perc1),
      fillOpacity = 0.7,
      color = NA,
      weight = 0,
      label = ~label_html
    )
  
  # SPECIAL LAYER
  if (nrow(special_ll) > 0) {
    map_widget <- map_widget |>
      leaflet::addPolygons(
        data = special_ll,
        fillColor = ~pal_special(special_class),
        fillOpacity = 0.9,
        color = NA,
        weight = 0,
        label = ~label_html
      )
  }
  
  # CATCHMENT
  if (!is.null(catchment_ll)) {
    map_widget <- map_widget |>
      leaflet::addPolygons(
        data = catchment_ll,
        fill = FALSE,
        color = "blue",
        weight = 1,
        opacity = 1
      )
  }
  
  # LEGEND (KEPT STYLE, FIXED ALIGNMENT)
  map_widget <- map_widget |>
    leaflet::addLegend(
      position = "bottomright",
      colors = c(
        "red",
        "#F7E3B1",
        normal_palette
      ),
      labels = c(
        "False positives",
        paste0("False negatives (obs pop > ", thresholdvalfortruth, ")"),
        labels
      ),
      title = paste0("Percentage errors (", pop_reference_year, ")"),
      opacity = 0.8
    )
  
  # SAVE
  htmlwidgets::saveWidget(
    widget = map_widget,
    file = output_path,
    selfcontained = TRUE
  )
  
  invisible(map_widget)
}

################################################################################
# VISUALISATION 11
save_histogram_errors_distributed_on_density_intervals <- function(census_grid_eval, 
                                                                   class_intervals_censusgrid, 
                                                                   census_grid_value_col = "TOT_P_2021",
                                                                   output_path) 
{ 
  
  observed_values <- census_grid_eval[[census_grid_value_col]]
  
  # ensure unique sorted breaks
  class_intervals_censusgrid <- sort(unique(class_intervals_censusgrid))
  
  if (length(class_intervals_censusgrid) < 2) {
    stop("Need at least 2 class interval breaks", call. = FALSE)
  }
  
  # create readable labels
  break_labels <- paste0(
    format(round(class_intervals_censusgrid[-length(class_intervals_censusgrid)]), big.mark = ","),
    "–",
    format(round(class_intervals_censusgrid[-1]), big.mark = ",")
  )
  
  # assign density classes
  density_class <- cut(
    observed_values,
    breaks = class_intervals_censusgrid,
    include.lowest = TRUE,
    right = FALSE,
    labels = break_labels
  )
  
  df_plot <- data.frame(
    density = observed_values,
    error   = census_grid_eval$dif1,
    class   = density_class
  )
  
  # remove NA
  df_plot <- df_plot[
    !is.na(df_plot$class) &
      !is.na(df_plot$error),
  ]
  
  # aggregate mean error per class
  avg_error_by_class <- aggregate(
    error ~ class,
    data = df_plot,
    FUN = mean
  )
  
  # ensure stable ordering
  avg_error_by_class$class <- factor(
    avg_error_by_class$class,
    levels = break_labels
  )
  
  # colors (recycle safely)
  base_cols <- RColorBrewer::brewer.pal(9, "YlOrRd")
  
  final_colors <- base_cols[
    seq_len(nrow(avg_error_by_class)) %% length(base_cols)
  ]
  if (length(final_colors) < nrow(avg_error_by_class)) {
    final_colors <- rep(base_cols, length.out = nrow(avg_error_by_class))
  }
  
  names(final_colors) <- avg_error_by_class$class
  
  # plotly histogram
  p <- plotly::plot_ly(
    data = avg_error_by_class,
    x = ~class,
    y = ~error,
    type = "bar",
    color = ~class,
    colors = final_colors,
    text = ~round(error, 2),
    textposition = "outside"
  ) |>
    plotly::layout(
      title = "Average absolute error per density class",
      xaxis = list(title = "Population density class"),
      yaxis = list(title = "Average absolute error"),
      showlegend = FALSE
    )
    
  # save HTML
  htmlwidgets::saveWidget(
    widget = p,
    file = output_path,
    selfcontained = TRUE
  )
  invisible(p)
}

################################################################################
# VISUALISATION 12
save_histogram_metrics_one_file <- function(metrics_weighted,
                                            metrics_simple,
                                            final_output_name) {

  # Weighted metrics
  metric_names <- setdiff(names(metrics_weighted), "popyear")
  metrics_long <- data.frame(
    metric = metric_names,
    value = as.numeric(metrics_weighted[1, metric_names]),
    group = "Weighted distribution"
  )
  
  # Unweighted metrics
  metric_names_simple <- setdiff(names(metrics_simple), "popyear")
  metrics_long_simple <- data.frame(
    metric = metric_names_simple,
    value = as.numeric(metrics_simple[1, metric_names_simple]),
    group = "Unweighted distribution"
  )
  
  # Combined metrics
  metrics_combined <- rbind(metrics_long, metrics_long_simple)

  # A few metric names are cell-classification counts rather than error
  # statistics, so they get a clarifying suffix in their displayed title
  metric_display_suffix <- c(
    number_of_wrong_cells_included = " (false positives)",
    number_of_correct_cells_excluded = " (false negatives)"
  )

  # Build master HTML page with each widget inlined (no iframes, no external files)
  html <- c(
    "<html>",
    "<head>",
    "<title>Metrics</title>",
    "</head>",
    "<body>"
  )

  # Use a temporary directory to hold individual widget HTML,
  # then read and inline each one into the master page
  tmp_dir <- tempdir()

  # Create one widget per metric
  for (metric_name in unique(metrics_combined$metric)) {
    
    plot_data <- metrics_combined[
      metrics_combined$metric == metric_name,
    ]

    metric_display_name <- paste0(
      metric_name,
      ifelse(
        metric_name %in% names(metric_display_suffix),
        metric_display_suffix[metric_name],
        ""
      )
    )

    p <- ggplot2::ggplot(
      plot_data,
      ggplot2::aes(
        x = group,
        y = value,
        fill = group,
        text = paste0(
          "Metric: ", metric_display_name, "<br>",
          "Group: ", group, "<br>",
          "Value: ", round(value, 3)
        )
      )
    ) +
      ggplot2::geom_col(width = 0.7) +
      ggplot2::geom_text(
        ggplot2::aes(label = round(value, 3)),
        vjust = -0.5
      ) +
      ggplot2::labs(
        title = paste0("Metric: ", metric_display_name),
        x = NULL,
        y = "Metric value",
        fill = "Distribution"
      ) +
      ggplot2::theme_minimal()
    
    p_widget <- plotly::ggplotly(
      p,
      tooltip = "text"
    )
    
    p_widget$height <- 400

    # Save to a temp file (selfcontained = TRUE so all JS/CSS is embedded)
    tmp_file <- file.path(
      tmp_dir,
      paste0("metric_", gsub("[^A-Za-z0-9_]", "_", metric_name), ".html")
    )

    htmlwidgets::saveWidget(
      p_widget,
      file = tmp_file,
      selfcontained = TRUE
    )

    # Read the full self-contained HTML and inline it into the master page
    widget_html <- readLines(tmp_file, warn = FALSE)

    html <- c(
      html,
      "<div style=\"width:100%;margin-bottom:30px;\">",
      widget_html,
      "</div>"
    )

    # Clean up temp file
    file.remove(tmp_file)
  }

  html <- c(
    html,
    "</body>",
    "</html>"
  )

  writeLines(
    html,
    file.path(final_output_name)
  )
  
  invisible(NULL)
}

################################################################################
# D2K WRAPPER
################################################################################

args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 29) {
  stop(
    paste(
      "Usage: Rscript src/create_visuatialisations.R",
      
      "<weight_table_rds_path>",
      "<clc_legend_rds_path>",
      "<coryear2018_rds_path>",
      "<output_input_weights_histogram_html_path>",
      
      "<cell_statistics_rds_path>",
      "<output_cor_distribution_across_lau_html_path>",
      
      "<censusgrid_rds_path>",
      "<evaluate_weighted_rds_path>",
      "<catchment_gpkg_path>",
      "<output_census_grid_map_html_path>",
      
      "<pop_focus_year_rds_path>",
      "<lau_in_catch_focus_rds_path>",
      "<output_lau_in_catch_focus_map_html_path>",
      
      "<lau_in_catch_reference_rds_path>",
      "<output_lau_in_catch_reference_map_html_path>",
      
      "<corineCLC_valid_rds_path>",
      "<output_corineCLC_valid_map_html_path>",
      
      "<corineCLC_only_potisive_rds_path>",
      "<output_corineCLCoverlappingPosCensusgrid_map_html_path>",
      
      "<refinement_rds_path>",
      "<output_refinement_map_html_path>",
      
      "<output_error_map_html_path>",

      "<thresholdval>",
      "<thresholdvalfortruth>",
      "<output_binaryPercError_map_html_path>",
      
      "<output_histogram_errorsDistributedOnDensClasses_html_path>",
      
      "<metrics_rds_path>",
      "<metrics_simple_rds_path>",
      "<output_histogram_metrics_html_path>"
    ),
    call. = FALSE
  )
}

weight_table_rds_path <- args[1]
clc_legend_rds_path <- args[2]
coryear2018_rds_path <- args[3]
corine_year <- readRDS(coryear2018_rds_path)
corine_year <- as.character(corine_year)
if (!(corine_year == "2018")) {
  stop(
    paste0(
      "Invalid corine year: ", corine_year,
      ". Allowed year is only year 2018", 
      collapse = ", "
    ),
    call. = FALSE
  )
}
output_input_weights_histogram_html_path <- args[4] # output 1

cell_statistics_rds_path <- args[5]
output_cor_distribution_across_lau_html_path <- args[6] # output 2

censusgrid_rds_path <- args[7]
evaluate_weighted_rds_path <- args[8]
catchment_gpkg_path <- args[9]
output_census_grid_map_html_path <- args[10] # output 3

pop_focus_year_rds_path <- args[11]
focus_year <- readRDS(pop_focus_year_rds_path)
focus_year <- as.character(focus_year)
valid_years <- c(
  "2024", "2023", "2022", "2021",
  "2020", "2019", "2018", "2017",
  "2016", "2015", "2014", "2013",
  "2012", "2011"
)
if (!(focus_year %in% valid_years)) {
  stop(
    paste0(
      "Invalid focus year: ", focus_year,
      ". Allowed years are: ",
      paste(valid_years, collapse = ", ")
    ),
    call. = FALSE
  )
}
lau_in_catch_focus_rds_path <- args[12] 
output_lau_in_catch_focus_map_html_path <- args[13] # output 4A

lau_in_catch_reference_rds_path <- args[14] 
output_lau_in_catch_reference_map_html_path <- args[15] # output 4B

corineCLC_valid_rds_path <- args[16]
output_corineCLC_valid_map_html_path <- args[17] # output 5A 

corineCLC_only_potisive_rds_path <- args[18]
output_corineCLCoverlappingPosCensusgrid_map_html_path <- args[19] # output 5B

refinement_rds_path <- args[20]
output_refinement_map_html_path <- args[21] # output 6

output_error_map_html_path <- args[22] # output 7

thresholdval <- args[23] #50
thresholdval <- as.numeric(thresholdval)
if (!isTRUE(thresholdval >= 0 && thresholdval <= 100)) {
  stop(
    paste0(
      "threshold value for percent errors to consider green must be between 0 and 100. Received: ",
      thresholdval
    ),
    call. = FALSE
  )
}
thresholdvalfortruth <- args[24] #10
thresholdvalfortruth <- as.numeric(thresholdvalfortruth)
if (!isTRUE(thresholdvalfortruth >= 0 && thresholdvalfortruth <= 100)) {
  stop(
    paste0(
      "threshold value for observed census grid must be between 0 and 100. Received: ",
      thresholdvalfortruth
    ),
    call. = FALSE
  )
}
output_binaryPercError_map_html_path <- args[25] # output 8

output_histogram_errorsDistributedOnDensClasses_html_path <- args[26] # output 9

metrics_rds_path <- args[27]
metrics_simple_rds_path <- args[28]
output_histogram_metrics_html_path <- args[29] # output 10

message("D2K Wrapper Started for creating evaluation datasets.")

tryCatch({
  
  # Read spatial focus object
  weight_table_final <- readRDS(weight_table_rds_path)
  if (!"percent" %in% names(weight_table_final)) {
    stop("Column 'percent' is missing")
  }
  
  # Read spatial focus object
  clc_legend <- readRDS(clc_legend_rds_path)
  
  cor_code_raster_columnname <- paste0("CODE_", 
                                       substr(corine_year, 
                                              3, 4)) # e.g. "CODE_18"
  
  
  #1 input weight histogram plot - produces input_weights - ANCILLARY
  save_weight_histogram(weight_table_final = weight_table_final,
                        clc_legend = clc_legend,
                        cor_code_raster_columnname = cor_code_raster_columnname,
                        output_path = output_input_weights_histogram_html_path)
  message("visualisation 1: Histogram created: input weight")
  
  # Read spatial focus object
  cell_counts <- readRDS(cell_statistics_rds_path)
  
  #2 histogram of number of LAU containing each urban CORINE class - lau_number
  save_cor_distribution_in_lau_histogram(cell_counts = cell_counts,
                                         cor_code_raster_columnname = cor_code_raster_columnname,
                                         clc_legend = clc_legend, 
                                         output_path = output_cor_distribution_across_lau_html_path) 
  message("visualisation 2: Histogram created: Corine CLC class area distribution")
  
  # Read spatial focus object
  censusgrid <- readRDS(censusgrid_rds_path)

  census_grid_value_col_resolved <- resolve_census_grid_value_col(censusgrid)
  pop_reference_year_resolved <- sub("^TOT_P_", "", census_grid_value_col_resolved)

  class_intervals_censusgrid <- get_censusgrid_labels(censusgrid = censusgrid,
                                                      census_grid_value_col = census_grid_value_col_resolved,
                                                      max_classes = 8)

  # Read spatial focus object
  evaluate_weighted_2021 <- readRDS(evaluate_weighted_rds_path)

  # Read spatial focus object
  catchment_gpkg <- sf::st_read(catchment_gpkg_path,
                                quiet = TRUE)

  #3 mapping census grid population (control data) - map_censusgrid (control data - and ancillary data)
  save_map_censusgrid_observed(census_grid_eval = evaluate_weighted_2021,
                               class_intervals_censusgrid = class_intervals_censusgrid,
                               catchment = catchment_gpkg,
                               output_path = output_census_grid_map_html_path,
                               census_grid_value_col = census_grid_value_col_resolved)
  message("visualisation 3: Map created: census grid 2021")
  
  lau_value_col_focus <- paste0("POP_", 
                                focus_year) 
  
  lau_in_catch_focus <- readRDS(lau_in_catch_focus_rds_path)
  lau_in_catch_focus <- sf::st_make_valid(lau_in_catch_focus)
  lau_in_catch_focus <- sf::st_cast(lau_in_catch_focus, "MULTIPOLYGON", warn = FALSE)
  
  #4A mapping observed LAU population at LAU level for focus year - map_LAUobs[year] (source data)
  save_map_lau_observed(lau_in_catchment = lau_in_catch_focus, 
                        lau_value_col = lau_value_col_focus,
                        lau_area_col = "AREA_KM2",
                        pop_year = focus_year,
                        catchment = catchment_gpkg,
                        output_path = output_lau_in_catch_focus_map_html_path) 
  message("visualisation 4: Map created: Observed LAU for focus year")
  
  lau_in_catch_reference <- readRDS(lau_in_catch_reference_rds_path)
  lau_in_catch_reference <- sf::st_make_valid(lau_in_catch_reference)
  lau_in_catch_reference <- sf::st_cast(lau_in_catch_reference, "MULTIPOLYGON", warn = FALSE)
  
  #4B mapping observed LAU population at LAU level for reference year - map_LAUobs[year] (reference data)
  save_map_lau_observed(lau_in_catchment = lau_in_catch_reference, 
                   lau_value_col = "POP_2021",
                   lau_area_col = "AREA_KM2",
                   pop_year = "2021",
                   catchment = catchment_gpkg,
                   output_path = output_lau_in_catch_reference_map_html_path)
  message("visualisation 5: Map created: Observed LAU for reference year 2021")
  
  corineCLC_valid <- readRDS(corineCLC_valid_rds_path)
  corineCLC_valid <- terra::unwrap(corineCLC_valid)
  
  cor_name_raster_columnname <- "LABEL"    
  
  #5A mapping valid corine raster for corine year 
  save_map_clc_observed(cor_rast_geom = corineCLC_valid,
                        clc_legend = clc_legend,
                        cor_name_raster_columnname = cor_name_raster_columnname,
                        cor_code_raster_columnname = cor_code_raster_columnname,
                        catchment = catchment_gpkg, 
                        textstring = "Applied ",
                        output_path = output_corineCLC_valid_map_html_path)
  message("visualisation 6: Map Created: Corine CLC 2018 cells applied in the refinement")
  
  corineCLC_all_overlapping_positive_censusgrid <- readRDS(corineCLC_only_potisive_rds_path)
  corineCLC_all_overlapping_positive_censusgrid <- terra::unwrap(corineCLC_all_overlapping_positive_censusgrid)
  
  #5B mapping populated corine raster for corine year - map_CLC[year]
  save_map_clc_observed(cor_rast_geom = corineCLC_all_overlapping_positive_censusgrid,
                        clc_legend = clc_legend,
                        cor_name_raster_columnname = cor_name_raster_columnname,
                        cor_code_raster_columnname = cor_code_raster_columnname,
                        catchment = catchment_gpkg, 
                        textstring = "Obs. pop. in ",
                        output_path = output_corineCLCoverlappingPosCensusgrid_map_html_path)
  message("visualisation 7: Map created: Corine CLC 2018 cells overlapping populated censusgrid 2021")
  
  refinement_focus <- readRDS(refinement_rds_path)

  #6 mapping estimated population at corine level for focus year 
  save_map_pop_estimated(est_pop_raster = refinement_focus, 
                         catchment = catchment_gpkg,
                         pop_year = focus_year, 
                         output_path = output_refinement_map_html_path)
  message("visualisation 8: Map created: Estimated population for focus year")
  
  #7 mapping absolute difference between estimated and observed population for 2011
  save_map_pop_errors_at_censusgrid(census_grid_eval = evaluate_weighted_2021,
                                    catchment = catchment_gpkg,
                                    pop_reference_year = pop_reference_year_resolved,
                                    census_grid_value_col = census_grid_value_col_resolved,
                                    output_path = output_error_map_html_path)
  message("visualisation 9: Map created: Absolute errors (over- and underestimation of people)")

  #8 mapping percentage difference between estimated and observed population for 2011
  save_map_pop_BinaryPercErrors_at_censusgrid(census_grid_eval = evaluate_weighted_2021,
                                              catchment = catchment_gpkg,
                                              pop_reference_year = pop_reference_year_resolved,
                                              thresholdval = thresholdval, #50
                                              census_grid_value_col = census_grid_value_col_resolved,
                                              thresholdvalfortruth = thresholdvalfortruth, #10
                                              output_path = output_binaryPercError_map_html_path)
  message("visualisation 10: Map created: Smaller vs. larger percentage errors")

  #print(names(evaluate_weighted_2021))
  #print(evaluate_weighted_2021$dif1)
  #print(sum(evaluate_weighted_2021$pop_est_cell1))
  #print(sum(evaluate_weighted_2021[[census_grid_value_col_resolved]]))

  #9 histogram over error distribution for each censusgrid-at-catchment population density class for weighted interpolation - histogram_errordist_[catchtype]_[reference_year]
  save_histogram_errors_distributed_on_density_intervals(census_grid_eval = evaluate_weighted_2021,
                                                         class_intervals_censusgrid = class_intervals_censusgrid,
                                                         census_grid_value_col = census_grid_value_col_resolved,
                                                         output_path = output_histogram_errorsDistributedOnDensClasses_html_path)
  message("visualisation 11: Histogram created: Absolute error distribution distributed out on observed density classes")
  
  metrics_weighted <- readRDS(metrics_rds_path)
  
  metrics_simple <- readRDS(metrics_simple_rds_path)
  
  #10 histogram of error metrics - metrics_[metric]_[reference_year]_[catchtype]
  save_histogram_metrics_one_file(metrics_weighted = metrics_weighted, 
                                  metrics_simple = metrics_simple,
                                  final_output_name = output_histogram_metrics_html_path)
  message("visualisation 12: Histogram created: Metrics")
  
  message("D2K Wrapper Finished. All visualisations are created.")
  
}, error = function(e) {
  stop(paste("Error during script execution:", e$message))
})
