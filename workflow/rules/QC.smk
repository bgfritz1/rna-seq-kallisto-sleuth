##########################################################
# Need to figure out how to handle paired-end data here
# getfastq input returns a tuple of [R1, R2]
##########################################################

rule fastqc_pretrim_f1:
    input:
        get_fastqs
    output:
        html="qc/fastqc/pretrim/{sample}-{unit}_1.html",
        zip="qc/fastqc/pretrim/{sample}-{unit}_1_fastqc.zip" # the suffix _fastqc.zip is necessary for multiqc to find the file. If not using multiqc, you are free to choose an arbitrary filename
    params: "--quiet"
    log:
        "logs/fastqc/{sample}-{unit}_1.log"
    threads: 1
    wrapper:
        "v0.86.0/bio/fastqc"

rule fastqc_pretrim_f2:
    input:
        get_fastqs_fq2
    output:
        html="qc/fastqc/pretrim/{sample}-{unit}_2.html",
        zip="qc/fastqc/pretrim/{sample}-{unit}_2_fastqc.zip" # the suffix _fastqc.zip is necessary for multiqc to find the file. If not using multiqc, you are free to choose an arbitrary filename
    params: "--quiet"
    log:
        "logs/fastqc/pretrim/{sample}-{unit}_2.log"
    threads: 1
    wrapper:
        "v0.86.0/bio/fastqc"

rule fastqc_posttrim_f1:
    input:
        "results/trimmed/{sample}-{unit}.1.fastq.gz"
    output:
        html="qc/fastqc/posttrim/{sample}-{unit}_1.html",
        zip="qc/fastqc/posttrim/{sample}-{unit}_1_fastqc.zip" # the suffix _fastqc.zip is necessary for multiqc to find the file. If not using multiqc, you are free to choose an arbitrary filename
    params: "--quiet"
    log:
        "logs/fastqc/{sample}-{unit}_1.log"
    threads: 1
    wrapper:
        "v0.86.0/bio/fastqc"

rule fastqc_posttrim_f2:
    input:
		"results/trimmed/{sample}-{unit}.2.fastq.gz"
    output:
        html="qc/fastqc/posttrim/{sample}-{unit}_2.html",
        zip="qc/fastqc/posttrim/{sample}-{unit}_2_fastqc.zip" # the suffix _fastqc.zip is necessary for multiqc to find the file. If not using multiqc, you are free to choose an arbitrary filename
    params: "--quiet"
    log:
        "logs/fastqc/posttrim/{sample}-{unit}_2.log"
    threads: 1
    wrapper:
        "v0.86.0/bio/fastqc"