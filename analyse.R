require(ggplot2)
require(scales)
require(dplyr)
require(maditr)
require(purrr)
require(tikzDevice)
require(ggpubr)

TIMEOUT <- 1
df0 <- read.csv("results.csv", header = TRUE, sep = ",")
df0$time[df0$time > TIMEOUT] <- TIMEOUT
df0$time[is.na(df0$time)] <- TIMEOUT
df0$memory[is.na(df0$memory)] <- max(df0$memory, na.rm = TRUE)
df <- dcast(data = df0, formula = instance + dataset ~ encoding, fun.aggregate = sum, value.var = c("answer", "time", "memory"))
df$time_min <- as.numeric(apply(df, 1, function (row) min(row["time_cd05"], row["time_cd06"],
                                                          row["time_d02"], row["time_cw"], row["time_sbk05"])))

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
interesting <- df[abs(df$answer_cw - df$answer_sbk05) > 0.01,]

nrow(df)

# Unique
sum(is.na(df$answer_cw) & !is.na(df$answer_cd05) & is.na(df$answer_cd06) &
      is.na(df$answer_d02) & is.na(df$answer_sbk05)) # cd05
sum(is.na(df$answer_cw) & is.na(df$answer_cd05) & !is.na(df$answer_cd06) &
      is.na(df$answer_d02) & is.na(df$answer_sbk05)) # cd06
sum(!is.na(df$answer_cw) & is.na(df$answer_cd05) & is.na(df$answer_cd06) &
      is.na(df$answer_d02) & is.na(df$answer_sbk05)) # cw
sum(is.na(df$answer_cw) & is.na(df$answer_cd05) & is.na(df$answer_cd06) &
      !is.na(df$answer_d02) & is.na(df$answer_sbk05)) # d02
sum(is.na(df$answer_cw) & is.na(df$answer_cd05) & is.na(df$answer_cd06) &
      is.na(df$answer_d02) & !is.na(df$answer_sbk05)) # sbk05

# Fastest
sum(!is.na(df$answer_cd05) & abs(df$time_cd05 - df$time_min) < 1e-5)
sum(!is.na(df$answer_cd06) & abs(df$time_cd06 - df$time_min) < 1e-5)
sum(!is.na(df$answer_cw) & abs(df$time_cw - df$time_min) < 1e-5)
sum(!is.na(df$answer_d02) & abs(df$time_d02 - df$time_min) < 1e-5)
sum(!is.na(df$answer_sbk05) & abs(df$time_sbk05 - df$time_min) < 1e-5)

# Solved
sum(!is.na(df$answer_cd05))
sum(!is.na(df$answer_cd06))
sum(!is.na(df$answer_cw))
sum(!is.na(df$answer_d02))
sum(!is.na(df$answer_sbk05))

# ================ Plots ==========================

# Scatter plot
min.time <- min(df0$time)
p1 <- ggplot(df[df$time_d02 > 0,], aes(x = time_d02, y = time_cw, col = major.dataset, shape = major.dataset)) +
  geom_point(alpha = 0.5, size = 1) +
  geom_abline(slope = 1, intercept = 0, colour = "#989898") +
  scale_x_continuous(trans = log10_trans(), limits = c(min.time, TIMEOUT), breaks = c(0.1, 10, 1000), labels = c("0.1", "10", "1000")) +
  scale_y_continuous(trans = log10_trans(), limits = c(min.time, TIMEOUT), breaks = c(0.1, 10, 1000), labels = c("0.1", "10", "1000")) +
  ylab("\\texttt{cw} time (s)") +
  xlab("\\texttt{d02} time (s)") +
  scale_color_brewer(palette = "Dark2", name = "Data set") +
  coord_fixed() +
  annotation_logticks(colour = "#b3b3b3") +
  theme_light() +
  labs(color = "Data set", shape = "Data set")
p2 <- ggplot(df[df$time_sbk05 > 0,], aes(x = time_sbk05, y = time_cw, col = major.dataset, shape = major.dataset)) +
  geom_point(alpha = 0.5, size = 1) +
  geom_abline(slope = 1, intercept = 0, colour = "#989898") +
  scale_x_continuous(trans = log10_trans(), limits = c(min.time, TIMEOUT), breaks = c(0.1, 10, 1000), labels = c("0.1", "10", "1000")) +
  scale_y_continuous(trans = log10_trans(), limits = c(min.time, TIMEOUT), breaks = c(0.1, 10, 1000), labels = c("0.1", "10", "1000")) +
  ylab("\\texttt{cw} time (s)") +
  xlab("\\texttt{sbk05} time (s)") +
  scale_color_brewer(palette = "Dark2", name = "Data set") +
  coord_fixed() +
  annotation_logticks(colour = "#b3b3b3") +
  theme_light() +
  labs(color = "Data set", shape = "Data set")
tikz(file = "paper/scatter.tex", width = 6.5, height = 2.5)
ggarrange(p1, p2, ncol = 2, common.legend = TRUE, legend = "right")
dev.off()

# Scatter plot: for a specific data set
ggplot(df[df$dataset == "2005-PGM"], aes(x = time_cw, y = time_sbk05)) +
  geom_point() +
  geom_abline(slope = 1, intercept = 0) +
  xlim(0, TIMEOUT) +
  ylim(0, TIMEOUT)

# Cumulative plot
cd05.times <- unique(df0$time[df0$encoding == "cd05"])
cd06.times <- unique(df0$time[df0$encoding == "cd06"])
d02.times <- unique(df0$time[df0$encoding == "d02"])
cw.times <- unique(df0$time[df0$encoding == "cw"])
sbk05.times <- unique(df0$time[df0$encoding == "sbk05"])
cumulative <- rbind(
  cbind(cd05.times, "cd05", unlist(cd05.times %>% map(function(x) sum(df0$time[df0$encoding == "cd05"] <= x)))),
  cbind(cd06.times, "cd06", unlist(cd06.times %>% map(function(x) sum(df0$time[df0$encoding == "cd06"] <= x)))),
  cbind(d02.times, "d02", unlist(d02.times %>% map(function(x) sum(df0$time[df0$encoding == "d02"] <= x)))),
  cbind(cw.times, "cw", unlist(cw.times %>% map(function(x) sum(df0$time[df0$encoding == "cw"] <= x)))),
  cbind(sbk05.times, "sbk05", unlist(sbk05.times %>% map(function(x) sum(df0$time[df0$encoding == "sbk05"] <= x)))))
cumulative <- as.data.frame(cumulative)
names(cumulative) <- c("time", "encoding", "count")
cumulative$encoding <- as.factor(paste("\\texttt{", cumulative$encoding, "}", sep = ""))
cumulative$time <- as.numeric(cumulative$time)
cumulative$count <- as.numeric(cumulative$count)
cumulative <- cumulative[cumulative$time < TIMEOUT, ]

tikz(file = "paper/cumulative.tex", width = 3, height = 1.6)
ggplot(cumulative, aes(x = time, y = count, color = encoding)) +
  geom_line(aes(linetype = encoding)) +
  scale_x_continuous(trans = log10_trans(), breaks = c(0.1, 10, 1000), labels = c("0.1", "10", "1000")) +
  xlab("Time (s)") +
  ylab("Instances solved") +
  scale_colour_brewer(palette = "Dark2") +
  scale_linetype_manual(breaks = c("\\texttt{cd05}", "\\texttt{cd06}", "\\texttt{cw}", "\\texttt{d02}",
                                   "\\texttt{sbk05}"), values = c(4, 3, 1, 5, 2)) +
  annotation_logticks(sides = "b", colour = "#989898") +
  theme_light() +
  labs(color = "Encoding", linetype = "Encoding")
dev.off()

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
