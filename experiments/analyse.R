require(ggplot2)
require(scales)
require(dplyr)
require(maditr)

TIMEOUT <- 60
df0 <- read.csv("results.csv", header = TRUE, sep = ",")
df0$time[df0$time > TIMEOUT] <- TIMEOUT
df0$time[is.na(df0$time)] <- TIMEOUT
df <- dcast(data = df0, formula = instance + dataset ~ encoding, fun.aggregate = sum, value.var = c("answer", "time"))

# Where answers don't match
interesting <- df[abs(df$answer_db20 - df$answer_d02) > 0.01,]

# Proportion of instances where my encoding is the best
# TODO: ignore rows with all NAs
#time$min <- apply(time, 1, min)
#sum(time$db20 == time$min)/nrow(time)

# Proportion unsolved
sum(is.na(df$answer_cd05))/nrow(df)
sum(is.na(df$answer_cd06))/nrow(df)
sum(is.na(df$answer_d02))/nrow(df)
sum(is.na(df$answer_db20))/nrow(df)
sum(is.na(df$answer_sbk05))/nrow(df)

# By dataset
ggplot(df, aes(x = time_db20, y = time_d02, col = dataset)) +
  geom_point() +
  geom_abline(slope = 1, intercept = 0) +
  xlim(0, TIMEOUT) +
  ylim(0, TIMEOUT)

ggplot(df[df$dataset == "2005-IJCAI"], aes(x = time_db20, y = time_d02)) +
  geom_point() +
  geom_abline(slope = 1, intercept = 0) +
  xlim(0, TIMEOUT) +
  ylim(0, TIMEOUT)

ggplot(df0, aes(x = encoding, y = time)) +
  geom_boxplot()
