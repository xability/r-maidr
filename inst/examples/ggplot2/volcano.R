# MAIDR Example: Volcano and Manhattan Plots (ggplot2) [experimental]
# Demonstrates accessible genomics scatter plots.
#
# A volcano plot puts each gene's effect size against its significance; a
# Manhattan plot puts each variant's position along the genome against it.
# Read as plain scatters they announce two coordinates per point and withhold
# what the chart is drawn for: which points cross the significance line, and
# which gene or SNP each one is. Read as volcano and Manhattan plots, MAIDR
# says how many points clear the threshold, lets the reader step through only
# those, and announces each point's label and group.
#
# maidr_volcano() and maidr_manhattan() are geom_point() with the threshold
# declared -- in the units y is announced in, with no default -- and `label`
# and `region` aesthetics for each point's name and group.

library(maidr)
library(ggplot2)

set.seed(42)
genes <- data.frame(
  gene = paste0("GENE", 1:300),
  log2fc = rnorm(300, sd = 1.2)
)
genes$padj <- pmin(1, exp(-abs(genes$log2fc) * runif(300, 1, 6)))
genes$regulation <- ifelse(
  genes$padj < 0.05 & abs(genes$log2fc) >= 1,
  ifelse(genes$log2fc > 0, "up", "down"),
  "not significant"
)

volcano <- ggplot(
  genes,
  aes(x = log2fc, y = -log10(padj), colour = regulation)
) +
  maidr_volcano(
    aes(label = gene, region = regulation),
    significance = -log10(0.05),
    effect = 1
  ) +
  # The threshold lines are references, not data; MAIDR leaves them out.
  geom_hline(yintercept = -log10(0.05), linetype = "dashed") +
  geom_vline(xintercept = c(-1, 1), linetype = "dashed") +
  labs(
    title = "Differential Expression",
    x = "log2 fold change",
    y = "-log10 adjusted p value",
    colour = "Regulation"
  ) +
  theme_minimal()

show(volcano)

# A Manhattan plot: positions offset by chromosome, axis labelled by
# chromosome, genome-wide significance at p < 5e-8.
snps <- data.frame(
  snp = paste0("rs", 1:600),
  chr = factor(rep(1:3, each = 200)),
  pos = rep(1:200, 3)
)
snps$bp <- snps$pos + (as.integer(snps$chr) - 1) * 200
snps$p <- runif(600)
snps$p[c(120, 121, 450)] <- c(3e-9, 1e-8, 6e-10)

manhattan <- ggplot(snps, aes(x = bp, y = -log10(p), colour = chr)) +
  maidr_manhattan(
    aes(label = snp, region = chr),
    significance = -log10(5e-8)
  ) +
  geom_hline(yintercept = -log10(5e-8), linetype = "dashed") +
  scale_x_continuous(breaks = c(100, 300, 500), labels = c("1", "2", "3")) +
  labs(
    title = "Genome-wide Association",
    x = "Chromosome",
    y = "-log10 p value"
  ) +
  theme_minimal() +
  theme(legend.position = "none")

show(manhattan)
