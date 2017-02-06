cwlVersion: v1.0
class: Workflow

requirements:
  - class: SubworkflowFeatureRequirement
  - class: ScatterFeatureRequirement
  - class: StepInputExpressionRequirement
  - class: InlineJavascriptRequirement
  - class: MultipleInputFeatureRequirement

inputs:
  upstream_fastq:
    type: File
  downstream_fastq:
    type: File?
  rsem_reference_name_dir:
    type: Directory
  rsem_reference_name:
    type: string?
    default: "ref"
  chrLengthFile:
    type: File
  aligner_type:
    type:
      name: "aligner_type"
      type: enum
      symbols: ["bowtie","star","bowtie2"]

outputs:
  rsem_isoform_results:
    type: File
    outputSource: rsem_calculate_expression/isoform_results
  rsem_gene_results:
    type: File
    outputSource: rsem_calculate_expression/gene_results
  rsem_genome_sorted_bam_bai_pair:
    type: File
    outputSource: rsem_calculate_expression/genome_sorted_bam_bai_pair
  bigwig_outfile:
    type: File
    outputSource: bamToBigwig/outfile

  isoforms_tpm_matrix:
    type: File
    outputSource: gen_matrices/isoforms_tpm_matrix
  isoforms_counts_matrix:
    type: File
    outputSource: gen_matrices/isoforms_counts_matrix
  genes_tpm_matrix:
    type: File
    outputSource: gen_matrices/genes_tpm_matrix
  genes_counts_matrix:
    type: File
    outputSource: gen_matrices/genes_counts_matrix

  bam_quality_log:
    type: File
    outputSource: bamtoolsStats/statsLog


steps:

  rsem_calculate_expression:
    run: ../../tools/rsem-calculate-expression.cwl
    in:
      upstream_read_file: upstream_fastq
      downstream_read_file: downstream_fastq
      reference_name_dir: rsem_reference_name_dir
      reference_name: rsem_reference_name
      star:
        source: aligner_type
        valueFrom: |
          ${
           if (self == "star"){
             return true;
           } else {
             return false;
           }
          }
      bowtie2:
        source: aligner_type
        valueFrom: |
          ${
           if (self == "bowtie2"){
             return true;
           } else {
             return false;
           }
          }
      sort_bam_by_coordinate:
        default: true
      output_genome_bam:
        default: true
      sample_name:
        source: upstream_fastq
        valueFrom: |
          ${
            return self.basename.split('.')[0];
          }
    out: [isoform_results, gene_results, genome_sorted_bam_bai_pair]

  bamtoolsStats:
    run: ../../tools/bamtools-stats.cwl
    in:
      inputFiles: rsem_calculate_expression/genome_sorted_bam_bai_pair
    out: [mappedreads, statsLog]

  bamToBigwig:
    run: bam-genomecov-bigwig.cwl
    in:
      input: rsem_calculate_expression/genome_sorted_bam_bai_pair
      genomeFile: chrLengthFile
      mappedreads: bamtoolsStats/mappedreads
      bigWig:
        source: upstream_fastq
        valueFrom: |
          ${
            return self.basename.split('.')[0]+".bigwig";
          }
    out: [outfile]

  files_to_folder:
    run: ../../expressiontools/files-to-folder.cwl
    in:
      input_files: [rsem_calculate_expression/isoform_results, rsem_calculate_expression/gene_results]
    out: [folder]

  gen_matrices:
    run: ../../tools/tpm_reads_matrix_gen.cwl
    in:
      input_directory: files_to_folder/folder
      prefix_name:
        source: upstream_fastq
        valueFrom: |
          ${
            return self.basename.split('.')[0]+"_";
          }
    out: [isoforms_tpm_matrix, isoforms_counts_matrix, genes_tpm_matrix, genes_counts_matrix]
