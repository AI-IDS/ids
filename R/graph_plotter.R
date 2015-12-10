#
#---- Configuration ----

configure <- function(day = 14) {
  c <- NULL
  c$num <- day
  c$days <- 12:17   # Days to process
  
  # Default global offset (if not loadable from labeler stats CSV)
  c$default_global_offset <- 18000
  
  # Filenames
  #csv_prefix <- "F:/ATAI_project/UNB/result_"
  csv_prefix  <- "M:/UiB/ATAI/UNB/result_"
  csv_suffix  <- ".csv"
  #xml_prefix <- "F:/ATAI_project/UNB/csv_min_labels_"
  xml_prefix  <-  "M:/UiB/ATAI/UNB/csv_min_labels_"
  xml_suffix  <- ".csv"
  
  c$csv_colnames_file <- "labeler_output_columns.csv"
  c$csv_file <- paste0(csv_prefix, day, csv_suffix)
  c$xml_file <- paste0(xml_prefix, day, xml_suffix)
  c$labeler_stats_file <- "M:/UiB/ATAI/UNB/labeler_stats.csv"
  c$csv_attack_label <- "Attack"
  
  # Histogram png
  regr_png_prefix <- "results/"
  regr_png_suffix <- "_hist.png"
  c$regr_png_file <- paste0(regr_png_prefix, day, regr_png_suffix)
  
  # Regression png
  hist_png_prefix <- "results/"
  hist_png_suffix <- "_regr.png"
  c$hist_png_file <-
    paste0(hist_png_prefix, day, hist_png_suffix)
  
  # PNG size
  c$png_x <- 900
  c$png_y <- 700
  
  # Summary PNGs
  c$render_summaries <- TRUE
  c$sum_regr_png_file <- "results/regr_sum.png"
  c$sum_hist_png_file <- "results/hist_sum.png"
  c$bigpng_x <- 2000
  c$bigpng_y <- 1500
  
  c$stats_outfile <- "results/stats.csv"
  c$sum_stats_outfile <- "results/sum_stats.csv"
  
  # Column names in input CSV features file in order
  c$csv_has_header <- FALSE
  c$csv_colnames <- c(
    "duration",
    "protocol_type",
    "service",
    "flag",
    "src_bytes",
    "dst_bytes",
    "land",
    "wrong_fragment",
    "urgent",
    "count",
    "srv_count",
    "serror_rate",
    "srv_serror_rate",
    "rerror_rate",
    "srv_rerror_rate",
    "same_srv_rate",
    "diff_srv_rate",
    "srv_diff_host_rate",
    "dst_host_count",
    "dst_host_srv_count",
    "dst_host_same_srv_rate",
    "dst_host_diff_srv_rate",
    "dst_host_same_src_port_rate",
    "dst_host_srv_diff_host_rate",
    "dst_host_serror_rate",
    "dst_host_srv_serror_rate",
    "dst_host_rerror_rate",
    "dst_host_srv_rerror_rate",
    "src_ip",
    "src_port",
    "dst_ip",
    "dst_port",
    "end_time",
    "label",
    "offset",
    "swapped"
  )
  
  
  conf <<- c
}
configure()

#---- Functions - Load data ----

# Load CSV file (labeler output)
load_csv <- function(fname, time_offset = 18000) {
  if (missing(fname)) {
    fname <- conf$csv_file
  }
  cat("Loading CSV labeled feature set '", fname, "'... ", sep = "")
  
  if (conf$csv_has_header) {
    csv <- read.csv(fname)
  } else {
    csv <-
      read.csv(fname, header = FALSE, col.names = conf$csv_colnames)
  }
  
  # Remove unlabeled samples
  csv <- subset(csv,!(csv$label %in% c("miss", "null")))
  
  # Transform data
  names(csv)[names(csv)=="end_time"] <- "time"
  csv$time <-
    strptime(csv$time, format = "%Y-%m-%dT%H:%M:%OS") - time_offset
  #csv$timestamp <- strtoi(format(csv$time, format = "%s"))
  if (!is.na(csv[1,]$swapped))
    csv$swapped <- (csv$swapped == "true")
  
  if (!is.na(csv[1,]$label))
    csv$assigned <- (!csv$label %in% c("miss", "null"))
  
  # Remove NA columns (if values are missing e.g. data not labeled)
  rem <- c()
  if (is.na(csv[1,]$label))
    rem <- c(rem, "label")
  if (is.na(csv[1,]$swapped))
    rem <- c(rem, "swapped")
  if (is.na(csv[1,]$offset))
    rem <- c(rem, "offset")
  csv <- csv[,!(colnames(csv) %in% rem), drop = FALSE]
  
  cat("Done.\n\n")
  return(csv)
}

# Remove unnecessary columns
minimize_csv <- function(csv) {
  keeps <- c ("time")
  
  if ("label" %in% colnames(csv))
    keeps <- c(keeps, "label")
  if ("swapped" %in% colnames(csv))
    keeps <- c(keeps, "swapped")
  if ("offset" %in% colnames(csv))
    keeps <- c(keeps, "offset", "assigned")
  
  min_csv <- csv[keeps]
  return(min_csv)
}

# Get assignment counts
get_assigned_csv <- function(csv) {
  if (!"assigned" %in% colnames(csv))
    return(NULL)
  
  csv_asgn <- csv[csv$assigned,]
  csv_asgn$offset <-
    as.numeric(levels(csv_asgn$offset)[csv_asgn$offset])
  return(csv_asgn)
}

# Load XML UNB labeled data transformed to csv
load_xml <- function(fname) {
  if (missing(fname)) {
    fname <- conf$xml_file
  }
  
  cat("Loading CSV version of XML label file '", fname, "'... ", sep = "")
  xml <- read.csv(fname)
  
  xml$time <-
    strptime(xml$stopDateTime, format = "%Y-%m-%dT%H:%M:%OS")
  
  cat("Done.\n\n")
  return(xml)
}

# Load labeler stats
load_labeler_stats <- function(fname) {
  if (missing(fname)) {
    fname <- conf$labeler_stats_file
  }
  
  cat("Loading Labeler stats '", fname, "'... ", sep = "")
  stats <- read.csv(fname)
  
  cat("Done.\n\n")
  return(stats)
}

#---- Functions - Plots ----

# Histograms
draw_hists <-
  function (xml, csv, csv_asgn = NULL, recalc_limits = TRUE, x_min_extra = 3600, x_max_extra = 3600, day_in_title = TRUE) {
    cat("Creating histograms: ")
    
    # Min & max for x axis
    if (recalc_limits) {
      cat("Calculating limits..")
      x_min <<-
        strtoi(format(min(min(xml$time),min(csv$time)),format = "%s")) - x_min_extra
      
      x_max <<-
        strtoi(format(max(max(xml$time),max(csv$time)),format = "%s")) + x_max_extra
    }
    
    title <- "Histogram of XML vs generated CSV time"
    if (day_in_title) {
      title <- paste0(title, " (day ", conf$num, ")")
      if (exists("labeler_stats")) {
        lstats <- get_labeler_day_stats(labeler_stats, conf$num)
        title <-
          paste0(title, "\nlabeler_global_offset=",-lstats$offset)
      }
    }
    
    # CSV counts
    cat("CSV..")
    csvcol <- rgb(0 / 255, 0 / 255, 200 / 255, alpha = 1)
    h.csv <<- hist(
      csv$time,
      freq = T,
      breaks = "hours",
      xlab = "Time",
      #ylim = c(0,150000),
      xlim = c(x_min,x_max),
      main = title,
      #border = csvcol,
      col.axis = "black",
      col = csvcol
    )
    
    # XML counts
    cat("XML..")
    xmlcol <- rgb(1,1,0.2,alpha = 0.7)
    h.xml <<- hist(
      xml$time,
      freq = T,
      breaks = "hours",
      col = xmlcol,
      col.axis = "black",
      border = "orange",
      axes = FALSE,
      add = TRUE
    )
    
    
    if (!is.null(csv_asgn)) {
      # Successful assignments
      succol <- rgb(255 / 255, 0 / 255, 0 / 255, alpha = 1)
      sucdens <- 20
      cat("Assignments..")
      h.asgnmnt <<- hist(
        csv_asgn$time,
        freq = T,
        breaks = "hours",
        axes = FALSE,
        col = succol,
        col.axis = "black",
        border = "red",
        density = sucdens,
        add = TRUE
      )
      
      # Attacks (only if there are some)
      cat("Attacks..")
      attcol <- rgb(1,0,1,alpha = 0.5)
      attdens <- NA #20
      if (length(csv_asgn[csv_asgn$label == "Attack",]$time) > 0) {
        h.attack <<- hist(
          csv_asgn[csv_asgn$label == "Attack",]$time,
          freq = T,
          breaks = "hours",
          axes = FALSE,
          col = attcol,
          col.axis = "black",
          border = "magenta",
          density = attdens,
          angle = 45,
          add = TRUE
        )
      } else {
        cat("NO attacks found")
      }
    }
    
    # Legend
    labels <- c("CSV (with offset)","XML (UNB)")
    fill <- c(csvcol, xmlcol)
    density = c(NA, NA)
    angle <- c(NA, NA)
    if (!is.null(csv_asgn)) {
      labels <- c(labels, "CSV Assigned","CSV Attacks")
      fill <- c(fill, succol, attcol)
      density = c(density, sucdens, attdens)
      angle <- c(angle, 45, NA)
    }
    legend(
      "topright",legend = labels, fill = fill, density = density, angle = angle
    )
    
    # TODO: dynamic y values here
    #     linevals <- c(25000, 50000, 75000, 10000)
    #     abline(h = linevals,
    #            col = rgb(0,0,0,0.3))
    #     axis(
    #       2, at = linevals, labels = linevals, col.axis = "black", col = "magenta"
    #     )
    
    cat(" Done.\n\n")
  }

# Plot offsets + regresion curve
draw_offset_regression <- function(csv_asgn, day_in_title = TRUE) {
  if (is.null(csv_asgn)) {
    cat("No time offset regression plot created (unlabeled data)\n\n")
    return(list(a = NA, b = NA))
  }
  
  cat("Creating time offset regression plot...")
  
  
  title <- "CSV time assignment offsets"
  if (day_in_title) {
    title <- paste0(title, " (day", conf$num, ")")
  }
  plot(
    offset ~ time,
    data = csv_asgn,
    main = title,
    xlab = "Time",
    ylab = "Time offset [s]"
  )
  lm <- lm(offset ~ time, data = csv_asgn)
  a <- lm$coefficients[2]
  b <- lm$coefficients[1]
  curve((a * x + b), col = "red", lwd = 2, add = TRUE)
  
  cat("Done\n")
  cat ("offset =",a,"* time +", b, "\n\n")
  
  return(list(a = a, b = b))
}

# Plot summary histogram & regression
draw_summaries <- function(all_xml, all_csv, all_ass_csv) {
  cat ("-------- PLOTTING SUMMARIES --------\n")
  
  # Assignment regression
  if (!is.null(all_ass_csv)) {
    png(
      conf$sum_regr_png_file, width = conf$bigpng_x, height = conf$bigpng_y
    )
    regr <<-
      draw_offset_regression(all_ass_csv, day_in_title = FALSE)
    dev.off()
  } else {
    regr <<- list(a = NA, b = NA)
  }
  
  # Histogram
  png(conf$sum_hist_png_file, width = conf$bigpng_x, height = conf$bigpng_y)
  draw_hists(all_xml, all_csv, all_ass_csv, day_in_title = FALSE)
  dev.off()
  
  cat("Done.\n")
  return(regr)
}

#---- Functions - Stats ----
# Expected assignment
# draw_hists() must be run before
get_expected_assignment_rate <- function(csv) {
  overlap <- pmin(h.csv$counts, h.xml$counts)
  ass_rate <- sum(overlap) / sum(h.xml$counts)
  return(ass_rate)
}

# Expected assignment
get_real_assignment_rate <- function(csv) {
  ass_rate <- nrow(csv[csv$assigned,]) / nrow(csv)
  return(ass_rate)
}

# Get labeler stats for given day
get_labeler_day_stats <- function(labeler_stats, day) {
  if (!day %in% labeler_stats$day)
    return(list(
      day = day, offset = NA, accuracy = NA
    ))
  
  return(as.list(labeler_stats[labeler_stats$day == day,]))
}

#---- Playground & debug area ----
test <- function(num) {
  configure(num)
  
  csv <- load_csv()
  csv <<- minimize_csv(csv)
  csv_asgn <<- get_assigned_csv(csv)
  xml <<- load_xml()
  
  draw_hists(xml, csv, csv_asgn, exists("x_min"))
  
  system.time(print(get_expected_assignment_rate(csv)))
}
if (FALSE) {
  test(16)
  draw_hists(xml, csv, csv_asgn, exists("x_min"))
  
  draw_offset_regression(csv_asgn)
}

#---- Main ----

main <- function(render_summaries) {
  t <- format(Sys.time(), format = "%Y-%m-%dT%H:%M:%OS")
  cat ("Main start time: ", t, "\n")
  configure()
  if (missing(render_summaries)) {
    render_summaries <- conf$render_summaries
  }
  
  # Labeler stats
  labeler_stats <<- load_labeler_stats()
  
  # Days to process
  days <<- conf$days
  
  # Prepare stats DF
  stats <<- data.frame(
    day = integer(),
    expected_assignment_rate = numeric(),
    real_assignment_rate = numeric(),
    labeler_assignment_rate = numeric(),
    labeler_global_offset = integer(),
    regression_a = numeric(),
    regression_b = numeric(),
    xml_records = integer(),
    csv_records = integer(),
    csv_assigned_records = integer(),
    attacks = numeric(),
    average_relative_offset = numeric()
  )
  
  # DFs from sumary dataset
  if (render_summaries) {
    all_xml <<- NULL
    all_csv <<- NULL
    all_ass_csv <<- NULL
  }
  
  for (i in days) {
    cat("-------- DAY", i, "--------\n")
    configure(i)
    
    # Labeler stats
    lstats <<- get_labeler_day_stats(labeler_stats, i)
    
    # Load & preprocess data
    xml <<- load_xml()
    global_csv_offset = ifelse(is.na(lstats$offset), conf$default_global_offset, -lstats$offset)
    csv <- load_csv(time_offset = global_csv_offset)
    csv <<- minimize_csv(csv)
    csv_asgn <<- get_assigned_csv(csv)
    
    # Add global offset & apply to time
    lstats <<- get_labeler_day_stats(labeler_stats, i)
    csv_asgn$offset <<- -csv_asgn$offset - lstats$offset
    
    # Add summary sets
    if (render_summaries) {
      all_xml <<- rbind(all_xml, xml)
      all_csv <<- rbind(all_csv, csv)
      if (!is.null(csv_asgn)) {
        all_ass_csv <<- rbind(all_ass_csv, csv_asgn)
      }
    }
    
    # Assignment regression
    if (!is.null(csv_asgn)) {
      png(conf$regr_png_file, width = conf$png_x, height = conf$png_y)
      regr <<- draw_offset_regression(csv_asgn)
      dev.off()
    } else {
      regr <<- list(a = NA, b = NA)
    }
    
    # Histogram
    png(conf$hist_png_file, width = conf$png_x, height = conf$png_y)
    draw_hists(xml, csv, csv_asgn)
    dev.off()
    
    # Stats
    exp_ass <- get_expected_assignment_rate(csv_asgn)
    real_ass <- get_real_assignment_rate(csv)
    if (!is.null(csv_asgn)) {
      csv_ass_cnt <- nrow(csv_asgn)
      avg_off <- mean(csv_asgn$offset + lstats$offset)
    } else {
      csv_ass_cnt <- NA
      avg_off <- NA
    }
    
    new_row <- c(
      i,
      exp_ass,
      real_ass,
      lstats$accuracy / 100,
      lstats$offset,
      regr$a,
      regr$b,
      nrow(xml),
      nrow(csv),
      csv_ass_cnt,
      nrow(csv[csv$label == conf$csv_attack_label,]),
      avg_off
    )
    stats[nrow(stats) + 1,] <<- new_row
  }
  
  # Add summary sets
  if (conf$render_summaries) {
    all_regr <- draw_summaries(all_xml, all_csv, all_ass_csv)
    
    # Summary stats
    ass_rate <- nrow(all_ass_csv) / nrow(all_csv)
    att_rate <-
      nrow(all_ass_csv[all_ass_csv$label == "Attack",]) / nrow(all_ass_csv)
    if (!is.null(all_ass_csv)) {
      all_csv_ass_cnt <- nrow(all_ass_csv)
    } else {
      all_csv_ass_cnt <- NA
    }
    all_stats <<- list(
      assignment_rate = ass_rate,
      attack_rate = att_rate,
      regression_a = all_regr$a,
      regression_b = all_regr$b,
      xml_records = nrow(all_xml),
      csv_records = nrow(all_xml),
      csv_assigned_records = all_csv_ass_cnt
    )
    cat(round(ass_rate * 100, 3), "% total assigment", sep = "")
    cat(round(att_rate * 100, 3), "% of all labeled are attacks", sep =
          "")
  }
  
  # Save & print stats
  write.csv(stats, file = conf$stats_outfile, row.names = FALSE)
  if (conf$render_summaries)
    write.csv(all_stats, file = conf$sum_stats_outfile, row.names = FALSE)
  print("Stats:")
  print(stats)
  
  t <- format(Sys.time(), format = "%Y-%m-%dT%H:%M:%OS")
  cat ("\nMain finish time: ", t, "\n")
  cat("All task done.\n")
}
main()
