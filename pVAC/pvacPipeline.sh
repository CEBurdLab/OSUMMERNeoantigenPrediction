#! /bin/bash

echo "Which sample would you like processed?"
read sample
echo "You chose $sample, Is that correct? y/n"
read -n 1 answer
if [ '$answer' == 'n' ]; then
	echo "\nExiting program"
	exit
else
	echo \n"Beginning process on sample: $sample"
fi

## Create Logfile
if [ ! -d "logfiles" ]; then
	mkdir logfiles
fi
logfile="logfiles/log_pVAC_$sample\_$(date +"%m%d%Y").txt"
echo -e "----------Starting New Execution:$(date +"%T")----------">>$logfile
commandoutput="logfiles/commandoutput_pVAC_$sample_$(date +"%m%d%Y%T").txt"
exec 2>>$commandoutput

## Adding VEP annotations to vcf file
echo "Running VEP on sample: $sample">>$logfile
/home/OSUMC.EDU/jens45/ensembl-vep/vep --input_file toAnalyze/$sample.snp_indel_hc.vcf --output_file output/$sample/$sample.vep.vcf --format vcf --vcf --symbol --terms SO --tsl --fasta /home/OSUMC.EDU/burd15/EAGLE/refFiles_GRC39/GRCm39.dna_sm.fa --gtf /home/OSUMC.EDU/jens45/00_refFiles/GRCm39/Mus_musculus.GRCm39.106.gtf.gz --offline --cache --species mus_musculus --merged --pick --transcript_version --dir_plugins /home/OSUMC.EDU/jens45/VEP_plugins --plugin Frameshift --plugin Wildtype --stats_text /output/$sample/$sample.stats.txt
eval $vep
echo "VEP complete.">>$logfile

## Adding coverage information to vcf file
echo "Creating sitelist for sample: $sample">>$logfile
vcf2bed1="vcf2bed < ~/EAGLE/output_GRCm39/$sample/$sample.snp.Somatic.hc.vcf | awk '{print $1"\t"$2"\t"$3}' > output/$sample/$sample.snp.list &"
vcf2bed2="vcf2bed < ~/EAGLE/output_GRCm39/$sample/$sample.indel.Somatic.hc.vcf | awk '{print $1"\t"$2"\t"$3}' > output/$sample/$sample.indel.list &"
eval $vcf2bed1
eval $vcf2bed2

echo "Running bam-readcount for sample: $sample">>$logfile
brc1="bam-readcount -f /home/OSUMC.EDU/burd15/EAGLE/refFiles_GRC39/GRCm39.dna_sm.fa -l output/$sample/$sample.indel.list ~/EAGLE/output_GRCm39_RNA/$sample/$sample\_sorted.bam -w1 -i -b 20 > output/$sample/$sample.indel.brc &"
brc2="bam-readcount -f /home/OSUMC.EDU/burd15/EAGLE/refFiles_GRC39/GRCm39.dna_sm.fa -l output/$sample/$sample.snp.list ~/EAGLE/output_GRCm39_RNA/$sample/$sample\_sorted.bam -w1 -b 20 > output/$sample/$sample.snv.brc &"
eval $brc1
eval $brc2

echo "Adding coverage information to VCF">>$logfile
~/vt/vt decompose -s output/$sample/$sample.vep.vcf -o output/$sample/$sample.decomp.vcf
vra1="vcf-readcount-annotator output/$sample/$sample.decomp.vcf output/$sample/$sample.snv.brc RNA -s TUMOR -t snv -o output/$sample/$sample.snv_rc_annot.vcf &"
vra2="vcf-readcount-annotator output/$sample/$sample.snv_rc_annot.vcf output/$sample/$sample.indel.brc RNA -s TUMOR -t indel -o output/$sample/$sample.rc_annot.vcf &"
eval $vra1
eval $vra2
echo "Coverage data has been added">>$logfile

## Adding expression data to the vcf file
echo "Adding expression data to sample: $sample">>$logfile
vea="vcf-expression-annotator output/$sample/$sample.rc_annot.vcf ~/EAGLE/output_GRCm39_RNA/$sample/genes.fpkm_tracking cufflinks gene -s TUMOR -o output/$sample/$sample.exp_annot.vcf &"
eval $vea
echo "Expression data has been added">>$logfile

## pVACseq
echo "Running pVACseq on sample: $sample">>$logfile
pvac="pvacseq run -t 8 output/$sample/$sample.exp_annot.vcf TUMOR H-2-Db,H-2-Kb,H2-IAb MHCflurry MHCnuggetsI MHCnuggetsII NNalign NetMHC SMM SMMPMBEC SMMalign output/$sample --iedb-install-directory /home/OSUMC.EDU/jens45/iedb &"
eval $pvac
echo "pVACseq complete">>$logfile
