require(ggplot2)
require(scales)
require(dplyr)
require(maditr)
require(purrr)
require(tikzDevice)
require(ggpubr)
require(tidyr)

TIMEOUT <- 1
data <- read.csv("../results.csv", header = TRUE, sep = ",")
data$time[data$time > TIMEOUT] <- TIMEOUT
data$time[is.na(data$time)] <- TIMEOUT
data$memory[is.na(data$memory)] <- max(data$memory, na.rm = TRUE)

# Choose one: (encoding or inference) and (old or new)
df0 <- data[data$stage == "old_enc", !colnames(data) %in% c("stage")]
df0 <- data[data$stage == "new_enc", !colnames(data) %in% c("stage")]
df0 <- data[data$stage == "old_inf", !colnames(data) %in% c("stage")]
df0 <- data[data$stage == "new_inf", !colnames(data) %in% c("stage")]

df <- dcast(data = df0, formula = instance + dataset ~ encoding,
            fun.aggregate = sum,
            value.var = c("answer", "time", "memory"))
df$time_min <- as.numeric(apply(df, 1, function (row) min(row["time_cd05"],
                                                          row["time_cd06"],
                                                          row["time_d02"],
                                                          row["time_cw"],
                                                          row["time_sbk05"])))

df$major.dataset <- "Non-binary"
df$major.dataset[grepl("DQMR", df$instance, fixed = TRUE)] <- "DQMR"
df$major.dataset[grepl("Grid", df$instance, fixed = TRUE)] <- "Grid"
df$major.dataset[grepl("mastermind", df$instance, fixed = TRUE)] <- "Mastermind"
df$major.dataset[grepl("blockmap", df$instance, fixed = TRUE)] <- "Random Blocks"
df$major.dataset[grepl("fs-", df$instance, fixed = TRUE)] <- "Other binary"
df$major.dataset[grepl("Plan_Recognition", df$instance, fixed = TRUE)] <- "Other binary"
df$major.dataset[grepl("students", df$instance, fixed = TRUE)] <- "Other binary"
df$major.dataset[grepl("tcc4f", df$instance, fixed = TRUE)] <- "Other binary"

# ============ Numerical investigations ================

df %>% group_by(df$dataset) %>% tally()

# Where answers don't match
interesting <- df[abs(df$answer_d02 - df$answer_bklm16) > 0.01,]

# Number of instances
nrow(df)

# Unique
# bklm16
sum(!is.na(df$answer_bklm16) & is.na(df$answer_cd05) & is.na(df$answer_cd06) &
      is.na(df$answer_cw) & is.na(df$answer_d02) & is.na(df$answer_sbk05))
# cd05
sum(is.na(df$answer_bklm16) & !is.na(df$answer_cd05) & is.na(df$answer_cd06) &
      is.na(df$answer_cw) & is.na(df$answer_d02) & is.na(df$answer_sbk05))
# cd06
sum(is.na(df$answer_bklm16) & is.na(df$answer_cd05) & !is.na(df$answer_cd06) &
      is.na(df$answer_cw) & is.na(df$answer_d02) & is.na(df$answer_sbk05))
# cw
sum(is.na(df$answer_bklm16) & is.na(df$answer_cd05) & is.na(df$answer_cd06) &
      !is.na(df$answer_cw) & is.na(df$answer_d02) & is.na(df$answer_sbk05))
# d02
sum(is.na(df$answer_bklm16) & is.na(df$answer_cd05) & is.na(df$answer_cd06) &
      is.na(df$answer_cw) & !is.na(df$answer_d02) & is.na(df$answer_sbk05))
# sbk05
sum(is.na(df$answer_bklm16) & is.na(df$answer_cd05) & is.na(df$answer_cd06) &
      is.na(df$answer_cw) & is.na(df$answer_d02) & !is.na(df$answer_sbk05))

# Fastest
sum(!is.na(df$answer_bklm16) & abs(df$time_bklm16 - df$time_min) < 1e-5)
sum(!is.na(df$answer_cd05) & abs(df$time_cd05 - df$time_min) < 1e-5)
sum(!is.na(df$answer_cd06) & abs(df$time_cd06 - df$time_min) < 1e-5)
sum(!is.na(df$answer_cw) & abs(df$time_cw - df$time_min) < 1e-5)
sum(!is.na(df$answer_d02) & abs(df$time_d02 - df$time_min) < 1e-5)
sum(!is.na(df$answer_sbk05) & abs(df$time_sbk05 - df$time_min) < 1e-5)

# Solved
sum(!is.na(df$answer_bklm16))
sum(!is.na(df$answer_cd05))
sum(!is.na(df$answer_cd06))
sum(!is.na(df$answer_cw))
sum(!is.na(df$answer_d02))
sum(!is.na(df$answer_sbk05))

# ================ Plots ==========================

# Scatter plot
min.time <- min(df0$time)
scatter_plot <- function(x_column, y_column, x_name, y_name) {
  ggplot(df[df[[x_column]] > 0,], aes(x = .data[[x_column]],
                                      y = .data[[y_column]],
                                      col = major.dataset,
                                      shape = major.dataset)) +
    geom_point(alpha = 0.5, size = 1) +
    geom_abline(slope = 1, intercept = 0, colour = "#989898") +
    scale_x_continuous(trans = log10_trans(), limits = c(min.time, TIMEOUT),
                       breaks = c(0.1, 10, 1000),
                       labels = c("0.1", "10", "1000")) +
    scale_y_continuous(trans = log10_trans(), limits = c(min.time, TIMEOUT),
                       breaks = c(0.1, 10, 1000),
                       labels = c("0.1", "10", "1000")) +
    ylab(paste0("\\texttt{", y_name, "} time (s)")) +
    xlab(paste0("\\texttt{", x_name, "} time (s)")) +
    scale_color_brewer(palette = "Dark2", name = "Data set") +
    coord_fixed() +
    annotation_logticks(colour = "#b3b3b3") +
    theme_light() +
    labs(color = "Data set", shape = "Data set")
}

p1 <- scatter_plot("time_d02", "time_cw", "d02", "cw")
p2 <- scatter_plot("time_sbk05", "time_cw", "sbk05", "cw")

tikz(file = "paper/scatter.tex", width = 6.5, height = 2.5)
ggarrange(p1, p2, ncol = 2, common.legend = TRUE, legend = "right")
dev.off()

# Cumulative plot
cumulative_plot <- function(column_name, pretty_column_name, column_values,
                            linetypes) {
  times <- vector(mode = "list", length = length(column_values))
  names(times) <- column_values
  for (value in column_values) {
    times[[value]] <- unique(df0$time[df0[column_name] == value])
  }
  chunks <- vector(mode = "list", length = length(column_values))
  names(chunks) <- column_values
  for (value in column_values) {
    chunks[[value]] <- cbind(times[[value]], value,
                             unlist(times[[value]] %>%
                                      map(function(x)
                                        sum(df0$time[df0[column_name] == value]
                                            <= x))))
  }
  cumulative <- as.data.frame(do.call(rbind, as.list(chunks)))
  names(cumulative) <- c("time", column_name, "count")
  cumulative[[column_name]] <- as.factor(paste("\\texttt{",
                                               cumulative[[column_name]], "}",
                                               sep = ""))
  cumulative$time <- as.numeric(cumulative$time)
  cumulative$count <- as.numeric(cumulative$count)
  cumulative <- cumulative[cumulative$time < TIMEOUT, ]
  ggplot(cumulative, aes(x = time, y = count, color = .data[[column_name]])) +
    geom_line(aes(linetype = .data[[column_name]])) +
    scale_x_continuous(trans = log10_trans(), breaks = c(0.1, 10, 1000), labels = c("0.1", "10", "1000")) +
    xlab("Time (s)") +
    ylab("Instances solved") +
    scale_colour_brewer(palette = "Dark2") +
    scale_linetype_manual(breaks = map(column_values, function(x) paste("\\texttt{", x, "}", sep = "")), values = linetypes) +
    annotation_logticks(sides = "b", colour = "#989898") +
    theme_light() +
    labs(color = pretty_column_name, linetype = pretty_column_name)
}

tikz(file = "paper/cumulative.tex", width = 3, height = 1.6)
cumulative <- cumulative_plot("encoding", "Encoding",
                c("bklm16", "cd05", "cd06", "d02", "cw", "sbk05"),
                c(6, 4, 3, 1, 5, 2))
dev.off()

# Numerical
max_d02 <- max(cumulative$count[cumulative$encoding == "\\texttt{d02}"])
interpolation <- approx(x = cumulative$count[cumulative$encoding == "\\texttt{cw}"],
                        y = cumulative$time[cumulative$encoding == "\\texttt{cw}"],
                        xout = max_d02)$y

# Scatter plot for memory usage (not interesting)
ggplot(df, aes(x = memory_cw, y = memory_cd06, col = major.dataset)) +
  geom_point(alpha = 0.5) +
  geom_abline(slope = 1, intercept = 0) +
  scale_x_continuous(trans = log10_trans(), limits = c(min(df0$memory), max(df0$memory))) +
  scale_y_continuous(trans = log10_trans(), limits = c(min(df0$memory), max(df0$memory))) +
  xlab("cw memory usage") +
  ylab("d02 memory usage") +
  scale_color_brewer(palette = "Dark2", name = "Data set")

# Cumulative plot for memory usage
times <- unique(df0$memory)
cumulative <- rbind.data.frame(
      cbind(times, "cd05", unlist(times %>% map(function(x) sum(df0$memory[df0$encoding == "cd05" & !is.na(df0$answer)] <= x)))),
      cbind(times, "cd06", unlist(times %>% map(function(x) sum(df0$memory[df0$encoding == "cd06" & !is.na(df0$answer)] <= x)))),
      cbind(times, "d02", unlist(times %>% map(function(x) sum(df0$memory[df0$encoding == "d02" & !is.na(df0$answer)] <= x)))),
      cbind(times, "cw", unlist(times %>% map(function(x) sum(df0$memory[df0$encoding == "cw" & !is.na(df0$answer)] <= x)))),
      cbind(times, "sbk05", unlist(times %>% map(function(x) sum(df0$memory[df0$encoding == "sbk05" & !is.na(df0$answer)] <= x)))))
names(cumulative) <- c("memory", "encoding", "count")
cumulative$encoding <- as.factor(paste("\\texttt{", cumulative$encoding, "}", sep = ""))
cumulative$memory <- as.numeric(cumulative$memory)
cumulative$count <- as.numeric(cumulative$count)

ggplot(cumulative, aes(x = memory/1024, y = count, color = encoding)) +
  geom_line() +
  scale_x_continuous(trans = log10_trans()) +
  xlab("Peak memory usage (MiB)") +
  ylab("Instances solved") +
  labs(color = "Encoding") +
  scale_colour_brewer(palette = "Dark2") +
  annotation_logticks(sides = "b", colour = "#989898") +
  theme_light()
