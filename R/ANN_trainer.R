# ANN trainer

#---- Dependencies ----
cat("Checking dependecies..\n")
dependencies <- c("neuralnet", "NeuralNetTools", "tcltk")
for (d in dependencies) {
  cat(d, "\n")
  # Try to install if not found
  if (!(d %in% rownames(installed.packages()))) {
    install.packages(d)
  }
  library(d, character.only = TRUE)
}

#---- Configuration ----
configure <- function(day = 14) {
  c <- NULL
  c$day <- day
  
  # Input files
  c$csv_has_header <- FALSE
  c$csv_colnames_file <- "labeler_output_columns.csv"
  
  csv_prefix  <- "M:/UiB/ATAI/UNB/result_"
  csv_suffix  <- ".csv"
  c$csv_dataset_file <- paste0(csv_prefix, day, csv_suffix)
  c$csv_attack_label <- "Attack"
  
  
  net_file_prefix  <- "M:/UiB/ATAI/UNB/net"
  net_file_suffix  <- ".rds"
  c$output_net_file <- paste0(net_file_prefix, day, net_file_suffix)
  
  # Column names in input file in order
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
  
  # Columns to remove (extra columns provided by extractor & labeler)
  c$dropped_columns <- c("src_ip", "src_port",
                         "dst_ip", "dst_port",
                         "end_time",
                         "offset", "swapped")
  
  # Columns to remove if one uniqe value and normalize
  c$normalized_columns <- c(
    "duration",
    "src_bytes",
    "dst_bytes",
    "wrong_fragment",
    "urgent",
    "count",
    "srv_count",
    "dst_host_count",
    "dst_host_srv_count"
  )
  
  # Columns to filter out if one unique value
  c$filtered_colums <- c(
    "protocol_type",
    "service",
    "flag",
    "land",
    "serror_rate",
    "srv_serror_rate",
    "rerror_rate",
    "srv_rerror_rate",
    "same_srv_rate",
    "diff_srv_rate",
    "srv_diff_host_rate",
    "dst_host_same_srv_rate",
    "dst_host_diff_srv_rate",
    "dst_host_same_src_port_rate",
    "dst_host_srv_diff_host_rate",
    "dst_host_serror_rate",
    "dst_host_srv_serror_rate",
    "dst_host_rerror_rate",
    "dst_host_srv_rerror_rate"
  )
  
  # Neural net & k-fold validation
  c$net_hidden <- 20
  c$net_threshold <- 0.1
  c$k_fold <- 10
  
  #....
  
  # Overwrite global conf
  conf <<- c
}
configure() # Set configuration

#---- Load & tranform dataset ----

# Load CSV dataset (labeler output)
load_dataset <- function(fname) {
  if (missing(fname)) {
    fname <- conf$csv_dataset_file
  }
  cat("Loading dataset from '", fname, "'...", sep = "")
  
  # Return object will contain dataset + normalization info
  ret <- list()
  
  # Load CSV
  if (conf$csv_has_header) {
    dataset <- read.csv(fname)
  } else {
    dataset <-
      read.csv(fname, header = FALSE, col.names = conf$csv_colnames)
  }
  
  cat("Transforming..")
  
  # Remove unlabeled samples
  dataset <- subset(dataset,!dataset$label %in% c("miss", "null"))
  
  # Remove unneeded columns added by extractor or labeler
  dataset <- dataset[,!(names(dataset) %in% conf$dropped_columns)]
  
  # Binarize label (create bool column "attack" & remove column "label")
  dataset$attack <- (dataset$label == conf$csv_attack_label) + 0
  dataset$label <- NULL
  
  # Stop if no attacks in dataset
  if (!(1 %in% dataset$attack)) {
    stop("Dataset contains NO attacks!");
  }
  
  # Get mins, maxs & scales for normalization
  norm_cols <- conf$normalized_columns
  mins <- apply(dataset[,norm_cols], 2, min)
  maxs <- apply(dataset[,norm_cols], 2, max)
  scales <- maxs - mins
  
  # Remove normalizable columns with one unique value (scale 0)
  drops <- names(scales[scales == 0])
  dataset <- dataset[,!(names(dataset) %in% drops)]
  norm_cols <- norm_cols[!(norm_cols %in% drops)]
  mins <- mins[!(names(mins) %in% drops)]
  #maxs <- maxs[!(names(maxs) %in% drops)]
  scales <- scales[scales != 0]
  
  # Normalize selected columns
  dataset[,norm_cols] <-
    as.data.frame(scale(dataset[,norm_cols], center = mins, scale = scales))
  
  # Return object: normalization  parameters
  ret$norm_mins <- mins
  ret$norm_scales <- scales
  
  # Remove columns with one unique value (those not normalized)
  filter_cols <- conf$filtered_colums
  unique_vals <-
    apply(dataset[,filter_cols], 2, function(x)
      (length(unique(x)) <= 1))
  drops2 <- names(unique_vals[unique_vals])
  dataset <- dataset[,!(names(dataset) %in% drops2)]
  
  # Return object: columns used
  ret$cols_used <- setdiff(names(dataset), "attack")
  ret$target_col <- "attack"
  
  # Binarize protocol_type values
  if ("protocol_type" %in% names(dataset)) {
    protocol_types = data.frame(Reduce(cbind,
                                       lapply(levels(dataset$protocol_type),
                                              function(x) {
                                                (dataset$protocol_type == x) + 0
                                              })))
    names(protocol_types) = paste0("protocol_type_", levels(dataset$protocol_type))
    dataset <- cbind(dataset, protocol_types)
    
    # Return object: protocol_type levels
    ret$levels_protocol_type <- levels(dataset$protocol_type)
    
    # Remove original column
    dataset$protocol_type <- NULL
  }
  
  # Binarize flag values
  if ("flag" %in% names(dataset)) {
    flags = data.frame(Reduce(cbind,
                              lapply(levels(dataset$flag),
                                     function(x) {
                                       (dataset$flag == x) + 0
                                     })))
    names(flags) = paste0("flag_", levels(dataset$flag))
    dataset <- cbind(dataset, flags)
    
    # Return object: flag levels
    ret$levels_flag <- levels(dataset$flag)
    
    # Remove original column
    dataset$flag <- NULL
  }
  
  # Binarize service values
  if ("service" %in% names(dataset)) {
    services = data.frame(Reduce(cbind,
                                 lapply(levels(
                                   dataset$service
                                 ),
                                 function(x) {
                                   (dataset$service == x) + 0
                                 })))
    names(services) = paste0("service_", levels(dataset$service))
    dataset <- cbind(dataset, services)
    
    # Return object: service levels
    ret$levels_service <- levels(dataset$service)
    
    # Remove original column
    dataset$service <- NULL
  }
  
  # Return object: actual data
  ret$data <- dataset
  
  cat("Done.\n\n")
  return(ret)
}

#---- Save neuralnet with normalization parameters ----
save_net <- function(neuralnet, dataset, fname) {
  if (missing(fname)) {
    fname <- conf$output_net_file
  }
  cat("Saving net & normalization to '", fname, "'...", sep = "")
  
  # Dataset preprocessing "metadata"
  net <- dataset[names(dataset) != "data"]
  
  # Add neuralnet without data
  net$neuralnet <- neuralnet[names(neuralnet) != "data"]
  
  saveRDS(net, fname)
  cat("Done\n\n")
}

# k-fold cross validation ----

# k= number of partitions
# nh= number of hidden neurons
# dataset= data
# returns the average mean square error

kfcv <- function(k = 10,hidden,data)
{
  # set the seed according to time
  set.seed(as.integer((
    as.double(Sys.time()) * 1000 + Sys.getpid()
  ) %% 2 ^ 31))
  
  # set the progress bar
  pb = tkProgressBar(
    title = "progress bar", min = 0, max = conf$k_fold, width = 300
  ) # initialize the progress bar
  
  # formula for the learner
  f <-
    as.formula(paste("attack ~", paste(names(data)[!names(data) %in% c("attack")], collapse = " + ")))
  
  # set the crossvalidation error
  e_p <- vector(mode = "numeric",length = k)
  # partition dataset
  folds <-
    cut(sample(1:nrow(data)), breaks = k, labels = FALSE)
  
  for (i in 1:k) {
    #split data
    train <- data[folds != i,]
    test <- data[folds == i,]
    
    #make a neural net
    net <-
      neuralnet(
        f, train, hidden = hidden, lifesign = "minimal", linear.output = FALSE, threshold = conf$net_threshold
      )
    results <- compute(net, test[,!(names(test) %in% c("attack"))])
    
    #compute mean sqared error
    e_p[i] <-
      sum((test$attack - results$net.result) ^ 2) / nrow(test)
    
    #update progressbar
    setTkProgressBar(pb, i, label = paste(round((i / k) * 100, 0),"% done"))
  }
  
  close(pb)
  
  return(mean(e_p))
}

# Get the best number of hidden neurons

net_setup <- function(layout = c(20,30,40,50,60),data)
{
  e_avg = sapply(layout,kfcv,k = conf$k_fold,data = data)
  
  return(layout[which.min(e_avg)])
}

# main

net_make <- function(data, hidden = net_setup(data = data))
{
  # formula for the learner
  f <-
    as.formula(paste("attack ~", paste(names(data)[!names(data) %in% c("attack")], collapse = " + ")))
  
  #make a neural net
  net_ids <-
    neuralnet(
      f, data, hidden, lifesign = "full", linear.output = FALSE, threshold = conf$net_threshold
    )
  return(net_ids)
}

net_mse <- function(net = net_make(data = data),data)
{
  results <- compute(net, data[,!(names(data) %in% c("attack"))])
  return(sum((data$attack - results$net.result) ^ 2) / nrow(data))
}

net_conf <-
  function(net = net_make(data = data),data, threshold = 0.5)
  {
    results <- compute(net, data[,!(names(data) %in% c("attack"))])
    table(data$attack,(results$net.result >= threshold) + 0)
  }

#---- Main ----



#---- Test ----

test_load_all <- function() {
  test_ds <<- NULL
  days <- c(12:15,17) # No attacks in day 16 - it would fail
  i <- 0
  for (d in days) {
    i <- i + 1
    configure(d)
    test_ds[[length(test_ds) + 1]] <<- load_dataset()
  }
  
  
  print("Lengths: ")
  for (i in 1:length(test_ds)) {
    print(nrow(test_ds[[i]]$data))
  }
  return(test_ds)
}

# Uncomment to run test
#system.time(test_load_all())

nets<<-NULL
test_nasrac <- function() {
  configure(14)
  
  
  xx <- load_dataset()
  dataset <- xx$data
  attacks<-dataset[dataset["attack"]==1,]
  normals<-dataset[dataset["attack"]==0,]
  #data<-rbind(attacks,normals[sample(1:nrow(normals),ceiling(5*nrow(attacks))),])
  data<-rbind(attacks,normals)[sample(1:(nrow(attacks)+nrow(normals)),1000),]
  net=net_make(data=data,50)
  #print(net_mse(net,normals))
  #print(net_mse(net,attacks))
  print(net_conf(net,rbind(attacks,normals)))
  nets[[length(nets) + 1]]=net
}
# Uncomment to run test
system.time(test_nasrac())