
if config["ref"]["type"] == "bacteria":
    rule get_transcriptome:
        output:
            "resources/transcriptome.{type}.fasta",
        log:
            "logs/get-transcriptome/{type}.log"
        params:
            accession = config["ref"]["accession"]
            datatype = {type}
        wildcard_constraints:
            type="cdna|cds|ncrna",
        cache: True
        script:
            "../scripts/get-genome-bacteria.py"
else: 
    rule get_transcriptome:
        output:
            "resources/transcriptome.{type}.fasta",
        log:
            "logs/get-transcriptome/{type}.log",
        params:
            species=config["resources"]["ref"]["species"],
            datatype="{type}",
            build=config["resources"]["ref"]["build"],
            release=config["resources"]["ref"]["release"],
        wildcard_constraints:
            type="cdna|cds|ncrna",
        cache: True
        wrapper:
            "0.74.0/bio/reference/ensembl-sequence"

rule get_annotation:
    output:
        "resources/genome.gtf",
    params:
        species=config["resources"]["ref"]["species"],
        release=config["resources"]["ref"]["release"],
        build=config["resources"]["ref"]["build"],
        fmt="gtf",
    log:
        "logs/get-annotation.log",
    cache: True
    wrapper:
        "0.80.1/bio/reference/ensembl-annotation"


rule get_transcript_info:
    output:
        "resources/transcript-info.rds",
    params:
        species=get_bioc_species_name(),
        version=config["resources"]["ref"]["release"],
    log:
        "logs/get_transcript_info.log",
    conda:
        "../envs/biomart.yaml"
    cache: True
    script:
        "../scripts/get-transcript-info.R"


rule get_pfam:
    output:
        r"resources/pfam/Pfam-A.{ext,(hmm|hmm\.dat)}",
    params:
        release=config["resources"]["ref"]["pfam"],
    log:
        "logs/get_pfam.{ext}.log",
    shell:
        "(curl -L ftp://ftp.ebi.ac.uk/pub/databases/Pfam/releases/"
        "Pfam{params.release}/Pfam-A.{wildcards.ext}.gz | "
        "gzip -d > {output}) 2> {log}"


rule convert_pfam:
    input:
        "resources/pfam/Pfam-A.hmm",
    output:
        multiext("resources/pfam/Pfam-A.hmm", ".h3m", ".h3i", ".h3f", ".h3p"),
    log:
        "logs/convert-pfam.log",
    conda:
        "../envs/hmmer.yaml"
    cache: True
    shell:
        "hmmpress {input} > {log} 2>&1"


rule calculate_cpat_hexamers:
    input:
        cds="resources/transcriptome.cds.fasta",
        ncrna="resources/transcriptome.ncrna.fasta",
    output:
        "resources/cpat.hexamers.tsv",
    log:
        "logs/calculate-cpat-hexamers.log",
    conda:
        "../envs/cpat.yaml"
    cache: True
    shell:
        "make_hexamer_tab.py --cod={input.cds} --noncod={input.ncrna} > {output} 2> {log}"


rule calculate_cpat_logit_model:
    input:
        hexamers="resources/cpat.hexamers.tsv",
        cds="resources/transcriptome.cds.fasta",
        ncrna="resources/transcriptome.ncrna.fasta",
    output:
        "resources/cpat.logit.RData",
    params:
        prefix=lambda _, output: output[0][:-12],
    log:
        "logs/calculate-cpat-logit-model.log",
    conda:
        "../envs/cpat.yaml"
    cache: True
    shell:
        "make_logitModel.py --hex={input.hexamers} --cgene={input.cds} "
        "--ngene={input.ncrna} -o {params.prefix} 2> {log}"
