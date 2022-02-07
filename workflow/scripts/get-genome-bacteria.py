import requests
import csv
import sys
import subprocess as sp
from snakemake.shell import shell

# Get species information
CSV_URL = "http://ftp.ensemblgenomes.org/pub/bacteria/current/species_EnsemblBacteria.txt"
accession = snakemake.params.accession.lower()

log = snakemake.log_fmt_shell(stdout=False, stderr=True)

success = False

with requests.get(CSV_URL) as r:
    lines = (line.decode('latin-1') for line in r.iter_lines()) 
    for row in csv.reader(lines, delimiter = "\t"):
        if row[5] == accession:
            ftp_info = row
            print(f"ID'd bacterial genome: {ftp_info[0]}")
            break
        
species_tag = ftp_info[1]
collection_id = ftp_info[13].split("_")[1]
assembly = ftp_info[4]

suffixes = ""

if datatype == "dna":
    suffixes = ["dna.toplevel.fa.gz"]
elif datatype == "cdna":
    suffixes = ["cdna.all.fa.gz"]
elif datatype == "cds":
    suffixes = ["cds.all.fa.gz"]
elif datatype == "ncrna":
    suffixes = ["ncrna.fa.gz"]
elif datatype == "pep":
    suffixes = ["pep.all.fa.gz"]
else:
    raise ValueError("invalid datatype, must be one of dna, cdna, cds, ncrna, pep")

for suffix in suffixes:
    URL = "http://ftp.ensemblgenomes.org/pub/bacteria/current/fasta/bacteria_{collection_id}_collection/{species_tag}/{datatype}/{species_tag_cap}.{assembly}.{suffix}".format(
        collection_id = collection_id,
        datatype = datatype,
        species_tag_cap = species_tag.capitalize(),
        species_tag = species_tag,
        suffix = suffix,
        assembly = assembly
    )
    try:
        shell("curl -sSf {url} > /dev/null 2> /dev/null")
    except sp.CalledProcessError:
        continue
    
    shell("(curl -L {url} | gzip -d > {snakemake.output[0]}) {log}")
    success = True
    break

if not success:
    print(
        "Unable to download requested sequence data from Ensemblbacteria. "
        "Did you check that this combination of species, build, and release is actually provided?",
        file=sys.stderr,
    )
    exit(1)     
