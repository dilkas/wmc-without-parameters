library(ggplot2)
library(scales)
library(dplyr)
library(maditr)
library(purrr)
library(tikzDevice)
library(ggpubr)
library(tidyr)

# TODO: plot treewidth vs add width
data <- read.csv("../results/results.csv", header = TRUE, sep = ",")

# TODO: remove (just for testing)
data <- data[data$dataset != "2004-PGM",]
data$encoding_time[grepl("pp$", data$encoding)] <- 0
data <- data[is.na(data$answer) | data$answer < 1e-10,]
data <- data[is.na(data$answer) | data$answer > 1e-3 & data$answer < 1,]
data$encoding_time <- 0

# TODO: how many times does each encoding produce the wrong answer?
temp <- data %>% left_join(data[data$encoding == "cd06" &
                                   data$novelty == "old",
                                 c("instance", "answer")], by = "instance") %>%
  left_join(data[data$encoding == "cw" & data$novelty == "new", c("instance", "answer")], by = "instance")
temp$answer.y <- ifelse(is.na(temp$answer.y), temp$answer, temp$answer.y)
removed <- temp[which(!is.na(temp$answer.y) & abs(temp$answer.x - temp$answer.y) > 0.01),]
temp <- temp[which(is.na(temp$answer.y) | abs(temp$answer.x - temp$answer.y) < 0.01),]
data <- subset(temp, select = -c(answer.y, answer))
names(data)[names(data) == 'answer.x'] <- 'answer'

TIMEOUT <- 1000
data$inference_time[is.na(data$inference_time)] <- TIMEOUT
min.time <- min(min(data$encoding_time[data$encoding_time > 0]),
                min(data$inference_time[data$inference_time > 0]))
data$encoding_time[data$encoding_time == 0] <- min.time
data$inference_time[data$inference_time == 0] <- min.time
data$answer[data$encoding_time >= TIMEOUT] <- NA
data$answer[data$inference_time >= TIMEOUT] <- NA
data$encoding_time[is.na(data$answer)] <- TIMEOUT
data$inference_time[is.na(data$answer)] <- TIMEOUT

# Merge 'novelty' and 'encoding' columns
data_merged <- data
data_merged$encoding <- paste(data_merged$novelty, data_merged$encoding, sep = "_")
data_merged <- subset(data_merged, select = -c(novelty))

# Add encoding and inference times
data_sum <- data_merged
data_sum$time <- data_sum$encoding_time + data_sum$inference_time
data_sum <- subset(data_sum, select = -c(inference_time, encoding_time))

# df <- dcast(data = data_sum, formula = instance + dataset ~ encoding,
#             fun.aggregate = NULL,
#             value.var = c("answer", "time", "add_width"))
df <- dcast(data = data_sum, formula = instance + dataset ~ encoding,
            fun.aggregate = NULL,
            value.var = c("answer", "time"))
time_columns <- Filter(function(x) startsWith(x, "time_"), names(df))
time_columns0 <- time_columns[!grepl('pp$', time_columns)]
for (column in time_columns) {
  df[is.na(df[[column]]), column] <- 2 * TIMEOUT
}

#df$treewidth <- apply(df %>% select(starts_with("treewidth")), 1,
#                      function(x) max(x, na.rm = TRUE))
#df <- df %>% select(!starts_with("treewidth_"))
#df$treewidth <- df$treewidth - 1
#df$zero_proportion <- apply(df %>% select(starts_with("zero_")), 1,
#                      function(x) max(x, na.rm = TRUE))
#df <- df %>% select(!starts_with("zero_proportion_"))
#df$count <- apply(df %>% select(starts_with("count_")), 1,
#                      function(x) max(x, na.rm = TRUE))
#df <- df %>% select(!starts_with("count_"))

df$time_min <- as.numeric(apply(df, 1, function (row) min(row[time_columns])))
df$time_min0 <- as.numeric(apply(df, 1, function (row) min(row[time_columns0])))
df$major.dataset <- "Non-binary"
df$major.dataset[grepl("DQMR", df$instance, fixed = TRUE)] <- "DQMR"
df$major.dataset[grepl("Grid", df$instance, fixed = TRUE)] <- "Grid"
df$major.dataset[grepl("mastermind", df$instance, fixed = TRUE)] <- "Mastermind"
df$major.dataset[grepl("blockmap", df$instance, fixed = TRUE)] <- "Random Blocks"
df$major.dataset[grepl("fs-", df$instance, fixed = TRUE)] <- "Other binary"
df$major.dataset[grepl("Plan_Recognition", df$instance, fixed = TRUE)] <- "Other binary"
df$major.dataset[grepl("students", df$instance, fixed = TRUE)] <- "Other binary"
df$major.dataset[grepl("tcc4f", df$instance, fixed = TRUE)] <- "Other binary"

instance_to_min_time <- df$time_min
names(instance_to_min_time) <- df$instance
instance_to_min_time0 <- df$time_min0
names(instance_to_min_time0) <- df$instance
# df.temp <- data.frame(instance = df$instance, dataset = NA, encoding = "VBS",
#                       answer = NA, time = instance_to_min_time[df$instance],
#                       add_width= max(data$add_width), treewidth = max(data$treewidth))
# df.temp2 <- data.frame(instance = df$instance, dataset = NA, encoding = "VBS*",
#                        answer = NA, time = instance_to_min_time0[df$instance],
#                        add_width = max(data$add_width), treewidth = max(data$treewidth))
df.temp <- data.frame(instance = df$instance, dataset = NA, encoding = "VBS",
                      answer = NA, time = instance_to_min_time[df$instance])
df.temp2 <- data.frame(instance = df$instance, dataset = NA, encoding = "VBS*",
                       answer = NA, time = instance_to_min_time0[df$instance])
data_sum <- rbind(data_sum, df.temp, df.temp2)
rownames(data_sum) <- c()

# ============ Numerical investigations ================

# Total time per data set (for job scheduling)
sum(data$encoding_time[startsWith(data$dataset, "Grid")]) + sum(data$inference_time[startsWith(data$dataset, "Grid")])
sum(data$encoding_time[startsWith(data$dataset, "DQMR")]) + sum(data$inference_time[startsWith(data$dataset, "DQMR")])
sum(data$encoding_time[startsWith(data$dataset, "Plan")]) + sum(data$inference_time[startsWith(data$dataset, "Plan")])
sum(data$encoding_time[startsWith(data$dataset, "2004")]) + sum(data$inference_time[startsWith(data$dataset, "2004")])
sum(data$encoding_time[startsWith(data$dataset, "2005")]) + sum(data$inference_time[startsWith(data$dataset, "2005")])
sum(data$encoding_time[startsWith(data$dataset, "2006")]) + sum(data$inference_time[startsWith(data$dataset, "2006")])

# The numbers of instances per data set (so I can check if each instance is included)
df %>% group_by(df$dataset) %>% tally()

# Where answers don't match
interesting <- df[abs(df$answer_old_cd06 - df$answer_new_bklm16) > 0.01,]
interesting <- df[abs(df$answer_old_cd06 - df$answer_new_bklm16pp) > 0.01,]
interesting <- df[abs(df$answer_old_cd06 - df$answer_new_d02) > 0.01,]
interesting <- df[abs(df$answer_old_cd06 - df$answer_new_sbk05) > 0.01,]

interesting <- df[abs(df$answer_old_cd06 - df$answer_old_bklm16) > 0.01,]
interesting <- df[abs(df$answer_old_cd06 - df$answer_old_cd05) > 0.01,]
interesting <- df[abs(df$answer_old_cd06 - df$answer_old_d02) > 0.01,]
interesting <- df[abs(df$answer_old_cd06 - df$answer_old_sbk05) > 0.01,]

# Number of instances
nrow(df)

# Unique
answer_columns <- Filter(function(x) startsWith(x, "answer_"), names(df))
for (column in answer_columns) {
  other_columns <- answer_columns[answer_columns != column]
  print(column)
  print(sum(apply(!is.na(df[[column]]) & is.na(df[,..other_columns]), 1, min)))
}

# Fastest
sum(!is.na(df$answer_new_bklm16) & abs(df$time_new_bklm16 - df$time_min) < 1e-5)
sum(!is.na(df$answer_new_bklm16pp) & abs(df$time_new_bklm16pp - df$time_min) < 1e-5)
sum(!is.na(df$answer_new_cd05pp) & abs(df$time_new_cd05pp - df$time_min) < 1e-5)
sum(!is.na(df$answer_new_cd06pp) & abs(df$time_new_cd06pp - df$time_min) < 1e-5)
sum(!is.na(df$answer_new_d02) & abs(df$time_new_d02 - df$time_min) < 1e-5)
sum(!is.na(df$answer_new_d02pp) & abs(df$time_new_d02pp - df$time_min) < 1e-5)
sum(!is.na(df$answer_new_sbk05) & abs(df$time_new_sbk05 - df$time_min) < 1e-5)

sum(!is.na(df$answer_old_bklm16) & abs(df$time_old_bklm16 - df$time_min) < 1e-5)
sum(!is.na(df$answer_old_cd05) & abs(df$time_old_cd05 - df$time_min) < 1e-5)
sum(!is.na(df$answer_old_cd06) & abs(df$time_old_cd06 - df$time_min) < 1e-5)
sum(!is.na(df$answer_old_d02) & abs(df$time_old_d02 - df$time_min) < 1e-5)
sum(!is.na(df$answer_old_sbk05) & abs(df$time_old_sbk05 - df$time_min) < 1e-5)

# Solved
sum(!is.na(df$answer_new_bklm16))
sum(!is.na(df$answer_new_bklm16pp))
sum(!is.na(df$answer_new_cd05pp))
sum(!is.na(df$answer_new_cd06pp))
sum(!is.na(df$answer_new_d02))
sum(!is.na(df$answer_new_d02pp))
sum(!is.na(df$answer_new_sbk05))

sum(!is.na(df$answer_old_bklm16))
sum(!is.na(df$answer_old_cd05))
sum(!is.na(df$answer_old_cd06))
sum(!is.na(df$answer_old_d02))
sum(!is.na(df$answer_old_sbk05))

# Calculate how many times cw is faster than d02 according to the cumulative plot
# (not updated)
max_d02 <- max(cumulative$count[cumulative$encoding == "\\texttt{d02}"])
interpolation <- approx(x = cumulative$count[cumulative$encoding == "\\texttt{cw}"],
                        y = cumulative$time[cumulative$encoding == "\\texttt{cw}"],
                        xout = max_d02)$y

# ================ Plots ==========================

# Scatter plot
scatter_plot <- function(df, x_column, y_column, x_name, y_name,
                         max.time) {
  ggplot(df[df[[x_column]] > 0,], aes(x = .data[[x_column]],
                                      y = .data[[y_column]],
                                      col = major.dataset,
                                      shape = major.dataset)) +
    geom_jitter(alpha = 1, size = 1, width = 0.1, height = 0.1) +
    geom_abline(slope = 1, intercept = 0, colour = "#989898") +
    scale_x_continuous(trans = log10_trans(), limits = c(min.time, max.time),
                       breaks = c(0.1, 10, 1000),
                       labels = c("0.1", "10", "1000")) +
    scale_y_continuous(trans = log10_trans(), limits = c(min.time, max.time),
                       breaks = c(0.1, 10, 1000),
                       labels = c("0.1", "10", "1000")) +
    ylab(y_name) +
    xlab(x_name) +
    coord_fixed() +
    annotation_logticks(colour = "#b3b3b3") +
    theme_light() +
    labs(shape = "Data set", colour = "Treewidth") +
#    scale_color_distiller("Treewidth", trans = "log") + # TODO: add breaks
    scale_shape("Data set")
}

scatter_plot(df, "time_old_cd06", "time_new_bklm16pp", "\\texttt{old_cd06} time (s)",
                   "\\texttt{new_bklm16++} time (s)", 2 * TIMEOUT)
scatter_plot(df, "time_new_bklm16", "time_new_bklm16pp", "\\texttt{bklm16} time (s)",
                   "\\texttt{bklm16++} time (s)", 2 * TIMEOUT)
scatter_plot(df, "add_width_new_d02pp", "add_width_new_d02", "\\texttt{d02++} width",
                   "\\texttt{d02} width", max(data$add_width))
scatter_plot(df, "add_width_new_bklm16pp", "add_width_new_sbk05", "\\texttt{bklm16++} width",
                   "\\texttt{sbk05} width", max(data$add_width))
scatter_plot(df, "treewidth", "add_width_new_bklm16", "treewidth",
                   "\\texttt{bklm16} width", max(data$add_width))

scatter_plot(data, "add_width", "inference_time", "ADD width", "time", 2 * TIMEOUT)

tikz(file = "paper/scatter.tex", width = 6.5, height = 2.5)
dev.off()

# Cumulative plot
cumulative_plot <- function(df, column_name, pretty_column_name, column_values,
                            linetypes, variable, variable_name) {
  times <- vector(mode = "list", length = length(column_values))
  names(times) <- column_values
  for (value in column_values) {
    times[[value]] <- unique(df[df[[column_name]] == value, variable])
  }
  chunks <- vector(mode = "list", length = length(column_values))
  names(chunks) <- column_values
  for (value in column_values) {
    chunks[[value]] <- cbind(times[[value]], value,
                             unlist(times[[value]] %>%
                                      map(function(x)
                                        sum(df[df[[column_name]] == value, variable]
                                            <= x))))
  }
  cumulative <- as.data.frame(do.call(rbind, as.list(chunks)))
  names(cumulative) <- c("time", column_name, "count")
  cumulative[[column_name]] <- as.factor(paste("\\texttt{",
                                               cumulative[[column_name]], "}",
                                               sep = ""))
  cumulative$time <- as.numeric(cumulative$time)
  cumulative$count <- as.numeric(cumulative$count)
  cumulative <- cumulative[cumulative$time < 2 * TIMEOUT, ]
  ggplot(cumulative, aes(x = time, y = count, color = .data[[column_name]])) +
    geom_line(aes(linetype = .data[[column_name]])) +
#    scale_x_continuous(trans = log10_trans(), breaks = c(0.1, 10, 1000), labels = c("0.1", "10", "1000")) +
    scale_x_continuous(trans = log10_trans()) +
    xlab("Time (s)") +
    ylab("Instances solved") +
#    scale_colour_brewer(palette = "Dark2") +
    scale_colour_manual(breaks = map(column_values, function(x)
      paste("\\texttt{", x, "}", sep = "")), values = c(1, 2, 3, 4, 5, 6, 7,
                                                        1, 3, 4, 5, 6, 7, 8, 8)) +
    scale_linetype_manual(breaks = map(column_values, function(x)
      paste("\\texttt{", x, "}", sep = "")), values = linetypes) +
    annotation_logticks(sides = "b", colour = "#989898") +
    theme_light() +
    labs(color = pretty_column_name, linetype = pretty_column_name)
}

# TODO: 11 lines in one plot is too much. Should I split it into two?
df2 <- data_sum[startsWith(data_sum$dataset, "2004") & !is.na(data_sum$dataset),]
df2 <- data_sum[startsWith(data_sum$dataset, "2005") & !is.na(data_sum$dataset),]
df2 <- data_sum[startsWith(data_sum$dataset, "2006") & !is.na(data_sum$dataset),]
df2 <- data_sum[startsWith(data_sum$dataset, "Grid") & !is.na(data_sum$dataset),]
df2 <- data_sum[startsWith(data_sum$dataset, "DQMR") & !is.na(data_sum$dataset),]
df2 <- data_sum[startsWith(data_sum$dataset, "Plan") & !is.na(data_sum$dataset),]
df2 <- data_sum
cumulative_plot(df2, "encoding", "Encoding",
                sort(unique(df2$encoding)),
                c(1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3), "time", "Time (s)")
cumulative_plot(df2, "encoding", "Encoding",
                sort(unique(df2$encoding)),
                c(1, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3, 3), "add_width", "ADD Width")

# Stacked bar plots comparing encoding and inference time
data_melted <- melt(data[!is.na(data$answer),], id = c("encoding", "novelty"),
                    measure = c("encoding_time", "inference_time")) %>%
  group_by(encoding, novelty, variable) %>%
  summarize(time = mean(value), lower = mean(value) - 0.1 * sd(value),
            upper = mean(value) + 0.1 * sd(value))
data_melted$lower[data_melted$variable =="inference_time"] <- with(data_melted, lower[variable == "encoding_time"] + lower[variable == "inference_time"])
data_melted$upper[data_melted$variable =="inference_time"] <- with(data_melted, upper[variable == "encoding_time"] + upper[variable == "inference_time"])
data_melted$novelty <- factor(data_melted$novelty, levels = c("old", "new"))
novelties <- c("Originally", "With DPMC")
names(novelties) <- c("old", "new")

ggplot(data_melted, aes(encoding, time, fill = variable)) +
  geom_bar(stat="identity", position = position_stack(reverse = TRUE)) +
  facet_grid(cols = vars(novelty), labeller = labeller(novelty = novelties)) +
  geom_errorbar(aes(ymin = lower, ymax = upper), width = 0.3, position = "identity") +
  theme_light() +
  scale_fill_brewer(palette = "Dark2", labels = c("Encoding", "Inference")) +
  xlab("") +
  ylab("Time (s)") +
  labs(fill = "")

# Plots that show how the combination of cw and cd06 would do (not including tree decomposition time)
fusion <- data.frame(treewidth = unique(data$treewidth))
fusion$tops <- apply(fusion, 1, function(x) nrow(df[ifelse(df$treewidth <= x, abs(df$time_new_bklm16 - df$time_min) < 0.01, abs(df$time_old_cd06 - df$time_min) < 0.01),]))
fusion$time <- apply(fusion, 1, function(x) sum(df$time_new_bklm16[df$treewidth <= x[1]]) + sum(df$time_old_cd06[df$treewidth > x[1]]))

ggplot(data = fusion, aes(x = treewidth, y = tops)) + geom_line() + scale_x_continuous(trans = log10_trans())
ggplot(data = fusion, aes(x = treewidth, y = time)) + geom_line() + scale_x_continuous(trans = log10_trans())
sum(!is.na(df$time_min))
sum(!is.na(df$answer_new_cw) & abs(df$time_new_cw - df$time_min) < 0.01)
sum(!is.na(df$answer_old_cd06) & abs(df$time_old_cd06 - df$time_min) < 0.01)
# TODO: add some horizontal lines to these plots that show the VBS, cd06, and cw scores

df$diff <- df$time_new_cw - df$time_old_cd06
df$diff <- df$time_new_bklm16 - df$time_old_cd06
ggplot(df, aes(treewidth, time_new_bklm16, shape = major.dataset, colour = major.dataset)) +
#  geom_jitter(width = 0.1, height = 0.1) +
  geom_point() +
  scale_x_continuous(trans = log10_trans()) +
  scale_y_continuous(trans = log10_trans())

# ADD width vs treewidth
ggplot(data, aes(treewidth, add_width, colour = encoding)) +
  geom_point(alpha = 0.5) +
  scale_x_continuous(trans = log10_trans()) +
  scale_y_continuous(trans = log10_trans())

ggplot(df, aes(add_width_new_bklm16, add_width_new_d02, color = major.dataset)) +
  geom_point() +
  scale_x_continuous(trans = log10_trans()) +
  scale_y_continuous(trans = log10_trans()) +
  geom_abline(slope = 1, intercept = 0, colour = "#989898")

df$diff <- df$add_width_new_d02 - df$add_width_new_d02pp
ggplot(df, aes(diff)) + geom_density()
ggplot(df, aes(diff)) + geom_boxplot()
