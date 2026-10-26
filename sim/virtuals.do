virtual type { \
1_Way\
2_Way\
4_Way\
8_Way\
} assoc_mode_t
virtual type { \
Type0_Raw\
B8_D1\
B8_D2\
All_Zeros\
B4_D1\
Same_Word\
} bdi_profile_t
virtual function -install /tb_paper_journal_artifacts/uut_bdi/compressor -env /tb_paper_journal_artifacts { (bdi_profile_t)/tb_paper_journal_artifacts/uut_bdi/compressor/compress_type} BDI_Profile_Name
virtual function -install /tb_paper_journal_artifacts/uut_bdi -env /tb_paper_journal_artifacts { (assoc_mode_t)/tb_paper_journal_artifacts/uut_bdi/dbg_current_sel} Associativity_Mode
