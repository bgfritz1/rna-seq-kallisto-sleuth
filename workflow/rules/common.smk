from snakemake.utils import validate
import pandas as pd


##### load config and sample sheets #####


validate(config, schema="../schemas/config.schema.yaml")

samples = pd.read_csv(config["samples"], sep="\t", dtype=str, comment="#").set_index(
    "sample", drop=False
)
samples.index.names = ["sample_id"]


def drop_unique_cols(df):
    singular_cols = df.nunique().loc[(df.nunique().values <= 1)].index
    return df.drop(singular_cols, axis=1)


samples = drop_unique_cols(samples)
validate(samples, schema="../schemas/samples.schema.yaml")

units = pd.read_csv(config["units"], dtype=str, sep="\t", comment="#").set_index(
    ["sample", "unit"], drop=False
)
units.index.names = ["sample_id", "unit_id"]
units.index = units.index.set_levels(
    [i.astype(str) for i in units.index.levels]
)  # enforce str in index
validate(units, schema="../schemas/units.schema.yaml")


report: "../report/workflow.rst"


##### wildcard constraints #####


wildcard_constraints:
    sample="|".join(samples.index),
    unit="|".join(units["unit"]),
    model="|".join(list(config["diffexp"].get("models", [])) + ["all"]),


####### helpers ###########


def is_activated(config_element):
    return config_element["activate"] in {"true", "True"}


def get_model(wildcards):
    if wildcards.model == "all":
        return {"full": None}
    return config["diffexp"]["models"][wildcards.model]


def is_single_end(sample, unit):
    """Determine whether unit is single-end."""
    fq2_not_present = pd.isnull(units.loc[(sample, unit), "fq2"])
    return fq2_not_present


def get_fastqs(wildcards):
    """Get raw FASTQ files from unit sheet."""
    if is_single_end(wildcards.sample, wildcards.unit):
        return units.loc[(wildcards.sample, wildcards.unit), "fq1"]
    else:
        u = units.loc[(wildcards.sample, wildcards.unit), ["fq1", "fq2"]].dropna()
        return [f"{u.fq1}", f"{u.fq2}"]


def get_trimmed(wildcards):
    if not is_single_end(**wildcards):
        # paired-end sample
        return expand(
            "results/trimmed/{sample}-{unit}.{group}.fastq.gz",
            group=[1, 2],
            **wildcards,
        )
    # single end sample
    return expand("results/trimmed/{sample}-{unit}.fastq.gz", **wildcards)


def get_bioc_species_name():
    first_letter = config["resources"]["ref"]["species"][0]
    subspecies = config["resources"]["ref"]["species"].split("_")[1]
    return first_letter + subspecies


def get_bioc_species_pkg(wildcards):
    """Get the package bioconductor package name for the the species in config.yaml"""
    species_letters = get_bioc_species_name()[0:2].capitalize()
    return "org.{species}.eg.db".format(species=species_letters)


def get_bioc_pkg_path(wildcards):
    return "resources/bioconductor/lib/R/library/{pkg}".format(
        pkg=get_bioc_species_pkg(wildcards)
    )


def kallisto_params(wildcards, input):
    extra = config["params"]["kallisto"]
    if len(input.fq) == 1:
        extra += " --single"
        extra += (
            " --fragment-length {unit.fragment_len_mean} " "--sd {unit.fragment_len_sd}"
        ).format(unit=units.loc[(wildcards.sample, wildcards.unit)])
    else:
        extra += " --fusion"
    return extra


def all_input(wildcards):
    """
    Function defining all requested inputs for the rule all (below).
    """

    wanted_input = []

    # request goatools if 'activated' in config.yaml
    if config["enrichment"]["goatools"]["activate"]:
        wanted_input.extend(
            expand(
                [
                    "results/tables/go_terms/{model}.go_term_enrichment.gene_fdr_{gene_fdr}.go_term_fdr_{go_term_fdr}.tsv",
                    "results/plots/go_terms/{model}.go_term_enrichment_{go_ns}.gene_fdr_{gene_fdr}.go_term_fdr_{go_term_fdr}.pdf",
                ],
                model=config["diffexp"]["models"],
                go_ns=["BP", "CC", "MF"],
                gene_fdr=str(config["enrichment"]["goatools"]["fdr_genes"]).replace(
                    ".", "-"
                ),
                go_term_fdr=str(
                    config["enrichment"]["goatools"]["fdr_go_terms"]
                ).replace(".", "-"),
            )
        )

    # request fgsea if 'activated' in config.yaml
    if config["enrichment"]["fgsea"]["activate"]:
        wanted_input.extend(
            expand(
                [
                    "results/tables/fgsea/{model}.all-gene-sets.tsv",
                    "results/tables/fgsea/{model}.sig-gene-sets.tsv",
                    "results/plots/fgsea/{model}.table-plot.pdf",
                    "results/plots/fgsea/{model}",
                ],
                model=config["diffexp"]["models"],
            )
        )

    # request spia if 'activated' in config.yaml
    if config["enrichment"]["spia"]["activate"]:
        wanted_input.extend(
            expand(
                ["results/tables/pathways/{model}.pathways.tsv"],
                model=config["diffexp"]["models"],
            )
        )

    # workflow output that is always wanted

    # general sleuth output
    wanted_input.extend(
        expand(
            [
                "results/plots/mean-var/{model}.mean-variance-plot.pdf",
                "results/plots/volcano/{model}.volcano-plots.pdf",
                "results/plots/interactive/volcano/{model}.svg",
                "results/plots/ma/{model}.ma-plots.pdf",
                "results/plots/qq/{model}.qq-plots.pdf",
                "results/tables/diffexp/{model}.transcripts.diffexp.tsv",
                # "results/plots/diffexp-heatmap/{model}.diffexp-heatmap.pdf", # see rule plot_diffexp_heatmap
                "results/tables/logcount-matrix/{model}.logcount-matrix.tsv",
            ],
            model=config["diffexp"]["models"],
        )
    )

    # ihw false discovery rate control
    wanted_input.extend(
        expand(
            [
                "results/tables/ihw/{model}.{level}.ihw-results.tsv",
                "results/plots/ihw/{level}/{model}.{level}.plot-dispersion.pdf",
                "results/plots/ihw/{level}/{model}.{level}.plot-histograms.pdf",
                "results/plots/ihw/{level}/{model}.{level}.plot-trends.pdf",
                "results/plots/ihw/{level}/{model}.{level}.plot-decision.pdf",
                "results/plots/ihw/{level}/{model}.{level}.plot-adj-pvals.pdf",
            ],
            model=config["diffexp"]["models"],
            level=["transcripts", "genes-aggregated", "genes-representative"],
        )
    )

    # sleuth p-value histogram plots
    wanted_input.extend(
        expand(
            "results/plots/diffexp/{model}.{level}.diffexp-pval-hist.pdf",
            model=config["diffexp"]["models"],
            level=["transcripts", "genes-aggregated", "genes-representative"],
        )
    )

    # technical variance vs. observed variance
    # wanted_input.extend(
    #        expand("results/plots/variance/{model}.transcripts.plot_vars.pdf", model=config["diffexp"]["models"]),
    #    )

    # PCA plots of kallisto results, each coloured for a different covariate
    wanted_input.extend(
        expand(
            [
                "results/plots/pc-variance/{covariate}.pc-variance-plot.pdf",
                "results/plots/loadings/{covariate}.loadings-plot.pdf",
                "results/plots/pca/{covariate}.pca.pdf",
            ],
            covariate=samples.columns[samples.columns != "sample"],
        )
    )

    # group-density plot
    wanted_input.extend(
        expand(
            ["results/plots/group_density/{model}.group_density.pdf"],
            model=config["diffexp"]["models"],
        )
    )

    # scatter plots
    if config["scatter"]["activate"]:
        wanted_input.extend(
            expand(
                ["results/plots/scatter/{model}.scatter.pdf"],
                model=config["diffexp"]["models"],
            )
        )

    # sleuth bootstrap plots
    wanted_input.extend(
        expand("results/plots/bootstrap/{model}", model=config["diffexp"]["models"])
    )

    # fragment length distribution plots
    wanted_input.extend(
        expand(
            "results/plots/fld/{unit.sample}-{unit.unit}.fragment-length-dist.pdf",
            unit=units[["sample", "unit"]].itertuples(),
        )
    )

    if is_activated(config["diffsplice"]):
        # diffsplice analysis
        wanted_input.extend(
            expand(
                "results/plots/diffsplice/{model}/{cons}",
                model=config["diffexp"]["models"],
                cons=["with_consequences", "without_consequences"],
            )
        )

    return wanted_input
