#!/usr/bin/env Rscript

#---- Dependencies ----
dependencies <- c("neuralnet")
for (d in dependencies) {
  #cat(d, "\n")
  # Try to install if not found
   if (!(d %in% rownames(installed.packages()))) {
     install.packages(d)
   
  library(d, character.only = TRUE)
}

#---- Config ----
configure <- function(day = 14) {
  c <- NULL
  c$day <- day
  
  # net_file_prefix  <- "M:/UiB/ATAI/UNB/net"
  net_file_prefix <- "models/net_"
  net_file_suffix  <- ".rds"
  c$net_file <- paste0(net_file_prefix, day, net_file_suffix)
  
  c$input_colnames <- c(
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
    "end_time"
  )
  
  # Column classes
  ch <- "character";  nu <- "numeric"
  c$input_colclasses <-
    c(nu, ch, ch, ch, rep(nu, 24), ch, nu, ch, nu, ch)
  
  # Overwrite global conf
  conf <<- c
}
configure()

#---- Load files ----

#Load net & other things from training
load_net <- function(fname) {
  if (missing(fname)) {
    fname <- conf$net_file
  }
  cat("Loading net & preprocessing params from '", fname, "'...", sep = "")
  
  # RDS is enough for one object
  net <- readRDS(fname)
  
  if (! ("day" %in% names(net)))
    net$day <- conf$day
  
  # Check presence of mandatory columns
  mandatory_cols <- c("cols_used", "target_col", "neuralnet")
  missing_cols <- setdiff(mandatory_cols, names(net))
  if (length(missing_cols) != 0) {
    stop(paste("Missing mandatory columns:", missing_cols))
  }
  
  cat("Done.\n\n")
  return(net)
}

#---- Prediction ----

preprocess <- function(net, data) {
  # This is maybe just an overhead for one row
  data <- data[, names(data) %in% net$cols_used]
  
  # Normalize some columns
  norm_cols <- names(net$norm_mins)
  data[,norm_cols] <-
    as.data.frame(scale(
      data[,norm_cols], center = net$norm_mins, scale = net$norm_scales
    ))
  
  # Binarize protocol_type values
  if ("levels_protocol_type" %in% names(net)) {
    protocol_types = data.frame(Reduce(cbind,
                                       lapply(net$levels_protocol_type,
                                              function(x) {
                                                (data$protocol_type == x) + 0
                                              })))
    names(protocol_types) = paste0("protocol_type_", net$levels_protocol_type)
    data <- cbind(data, protocol_types)
    
    # Remove original column
    data$protocol_type <- NULL
  }
  
  # Binarize flag values
  if ("levels_flag" %in% names(net)) {
    flags = data.frame(Reduce(cbind,
                              lapply(net$levels_flag,
                                     function(x) {
                                       (data$flag == x) + 0
                                     })))
    names(flags) = paste0("flag_", net$levels_flag)
    data <- cbind(data, flags)
    
    # Remove original column
    data$flag <- NULL
  }
  
  # Binarize service values
  if ("levels_service" %in% names(net)) {
    services = data.frame(Reduce(cbind,
                                 lapply(net$levels_service,
                                        function(x) {
                                          (data$service == x) + 0
                                        })))
    names(services) = paste0("service_", net$levels_service)
    data <- cbind(data, services)
    
    # Remove original column
    data$service <- NULL
  }
  
  return(data)
}

# Prediction
comp <- function(net, line) {
  data <- read.table(
    text = line, sep = ",",
    colClasses = conf$input_colclasses,
    header = FALSE,
    col.names = conf$input_colnames
  )
  
  data <- preprocess(net, data)
  
  results <- compute(net$neuralnet, data)
  
  return(results)
}

#---- Test ----

test_it <- function() {
  configure(14)
  net <- load_net()
  
  line <-
    "0,tcp,http_443,OTH,55,0,0,0,0,0,11,0.00,0.00,0.00,0.00,0.00,0.00,1.00,0,11,0.00,0.00,0.00,1.00,0.00,0.00,0.00,0.00,192.168.0.2,33208,199.16.156.120,443,2015-11-28T17:38:59"

  result <- comp(net$neuralnet, line)
  print(result)
}
#test_it()


#---- Main ----


main <- function () {
  isRStudio <- Sys.getenv("RSTUDIO") == "1"
  if (isRStudio) {
    stop("This should be run from command line, RStudio detected")
  }
  
  # Load nets
  attacks=c("Local","DoS","DDoS","BFSSH")
  days <- c(13,14,15,17)
  nets <- NULL
  for (i in days)
  {
    configure(i)
    nets[[length(nets)+1]] <- load_net()
  }
  
  
  results <- NULL
  f <- file("stdin")
  open(f)
  while (length(line <- readLines(f,n = 1)) > 0) {
    
    results<-NULL
    for (i in 1:length(days))
    {
      configure(nets[[i]]$day)
      result <- comp(nets[[i]], line)
      results[[length(results)+1]]=result$net.result
    }
    
    # Threshold
    res <- ifelse(sum(results>0.95)==0,"Normal",attacks[which.max(results)])
  
    #cat(line,",", sep="")
    #print(results)
    a <- paste(round(results, 8), sep=" ")
    cat(res, a, "\n", sep=" ")
    
  }
  
  close(f)
  cat("Dovi dopi ci")
  
}
main()