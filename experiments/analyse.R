require(ggplot2)
require(scales)
require(dplyr)
require(maditr)

df <- read.csv("results.csv", header = TRUE, sep = ",")
answers <- dcast(data = df, formula = instance ~ encoding, fun.aggregate = sum, value.var = "answer")
time <- dcast(data = df, formula = instance ~ encoding, fun.aggregate = sum, value.var = "time")

answers[answers$db20 - answers$d02 > 0.01,]
interesting <- answers[answers$db20 - answers$sbk05 > 0.01,]

# ================= older stuff =======================

sang.data <- df[df$encoding == "sang",]
conditional.data <- df[df$encoding == "conditional",]

# Numbers of unsolved instances (incomplete)
sum(is.na(sang.data$answer))
sum(is.na(conditional.data$answer))

summary(sang.data$time)
summary(conditional.data$time)

# NOTE: Some timed out instances are omitted from this
merged <- merge(sang.data, conditional.data, by = "instance")
merged$difference <- merged$time.x - merged$time.y
merged$relative.difference <- merged$difference / merged$time.x
# The percentage of instances where my encoding is better
nrow(merged[merged$time.y < merged$time.x,])/nrow(merged)
summary(merged$difference)

ggplot(merged, aes(x = time.x, y = time.y)) +
  geom_point() +
  geom_abline(slope = 1, intercept = 0) +
#  scale_x_continuous(trans = log2_trans()) +
#  scale_y_continuous(trans = log2_trans()) +
  xlab("Inference time for the encoding by Sang et al.") +
  ylab("Inference time for the conditional encoding")

ggplot(df, aes(x = time, y = encoding)) +
  geom_boxplot()

ggplot(merged, aes(x = difference)) +
  geom_histogram(binwidth = 1)

ggplot(merged, aes(x = relative.difference)) +
  geom_histogram(binwidth = 0.1) +
  scale_x_continuous(breaks = round(seq(min(merged$relative.difference, na.rm = TRUE),
                                        max(merged$relative.difference, na.rm = TRUE), by = 0.5), 1))

quantile(merged$relative.difference, 0.90, na.rm = TRUE)
quantile(merged$relative.difference, 0.10, na.rm = TRUE)
summary(merged$relative.difference)
median(merged$relative.difference, na.rm = TRUE)
# The running time of a typical instance is reduced by 74%

# TL;DR: Almost never worse. Usually better by only a small amount, but sometimes significantly better.
