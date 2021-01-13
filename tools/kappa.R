library(viridis)
library(ggplot2)

kappa <- function(treewidth, valuewidth) {
  s <- valuewidth
  t <- valuewidth
  cat("treewidth:", treewidth, ", valuewidth: ", valuewidth, "\n")
  for (i in seq(treewidth, 1, by = -1)) {
#    if (2^(i-1) < t*(t-1)) {
#      print("exponential is smaller")
#    } else {
#      print("quadratic is smaller")
#    }
    t <- min(2^(i-1), s*(s-1))
    s <- s + t
  }
  return(s)
}

MIN <- 2
MAX <- 100
df <- data.frame(treewidth = rep(MIN:MAX, MAX-MIN+1),
                 valuewidth = rep(MIN:MAX, each=MAX-MIN+1))
df$kappa <- Vectorize(kappa)(df$treewidth, df$valuewidth)
df$kappa2 <- (2^df$treewidth + df$valuewidth - df$kappa) / df$kappa
ggplot(df, aes(treewidth, valuewidth, fill = kappa)) + geom_tile() +
  scale_fill_viridis(trans = "log") +
#  geom_text(aes(label = round(kappa, 1))) +
  scale_x_continuous(breaks = MIN:MAX) +
  scale_y_continuous(breaks = MIN:MAX)
