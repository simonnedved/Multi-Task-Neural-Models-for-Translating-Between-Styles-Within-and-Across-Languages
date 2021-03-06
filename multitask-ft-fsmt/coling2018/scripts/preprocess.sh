#!/bin/bash

# True-casing
tc_model=$sub_data_dir/tc.$lang_base
if [ ! -f $tc_model ]; then
	echo " * Training truecaser using $train.* ..."
	cat $train.$lang_1 $train.$lang_2 > $sub_data_dir/tc.corpus.tmp
	$moses_scripts_path/recaser/train-truecaser.perl \
		-corpus $sub_data_dir/tc.corpus.tmp           \
		-model $tc_model
	rm $sub_data_dir/tc.corpus.tmp
fi;
for type in train dev_1 dev_2; do
	for lang in $lang_1 $lang_2; do
		if [ -f ${!type}.$lang ] && [ ! -f $sub_data_dir/$type.tok.tc.$lang ]; then
			echo " * True-casing ${!type}.$lang ..."
			$moses_scripts_path/recaser/truecase.perl \
				-model $tc_model                       \
				< ${!type}.$lang                        \
				> $sub_data_dir/$type.tok.tc.$lang
		fi;
	done;
done;

# Byte Pair Encoding (BPE)
bpe_model=$sub_data_dir/bpe.$lang_base
if [ ! -f $bpe_model ]; then
	echo " * Training BPE using $sub_data_dir/train.tok.tc.* ..."
	cat $sub_data_dir/train.tok.tc.$lang_1 $sub_data_dir/train.tok.tc.$lang_2 \
		| python2 $bpe_scripts_path/learn_bpe.py \
			-s $bpe_num_operations \
			> $bpe_model
fi;
for type in train dev_1 dev_2; do
	for lang in $lang_1 $lang_2; do
		if [ -f $sub_data_dir/$type.tok.tc.$lang ] && [ ! -f $sub_data_dir/$type.tok.tc.bpe.$lang ]; then
			echo " * Applying BPE to $sub_data_dir/$type.tok.tc.$lang ..."
			python2 $bpe_scripts_path/apply_bpe.py \
				--codes $bpe_model                  \
				< $sub_data_dir/$type.tok.tc.$lang   \
				> $sub_data_dir/$type.tok.tc.bpe.$lang
		fi;
	done;
done;

# Language-tagging and concatenating data
if [ ! -f $sub_data_dir/train.src ]; then
	echo " * Adding language tags to $sub_data_dir/train.src ..."
	cat $sub_data_dir/train.tok.tc.bpe.$lang_1 | sed "s/^/<2$lang_2> /" >> $sub_data_dir/train.src
	cat $sub_data_dir/train.tok.tc.bpe.$lang_2 | sed "s/^/<2$lang_1> /" >> $sub_data_dir/train.src
	cat $sub_data_dir/train.tok.tc.bpe.$lang_2 $sub_data_dir/train.tok.tc.bpe.$lang_1 >> $sub_data_dir/train.tgt
	if [[ $identical_ft == True ]]; then
		cat $sub_data_dir/train.tok.tc.bpe.$lang_1 | sed "s/^/<2$lang_1> /" >> $sub_data_dir/train.src
		cat $sub_data_dir/train.tok.tc.bpe.$lang_2 | sed "s/^/<2$lang_2> /" >> $sub_data_dir/train.src
		cat $sub_data_dir/train.tok.tc.bpe.$lang_1 $sub_data_dir/train.tok.tc.bpe.$lang_2 >> $sub_data_dir/train.tgt
	fi;
fi;
if [ ! -f $sub_data_dir/dev.src ]; then
	echo " * Adding language tags to $sub_data_dir/dev.src ..."
	cat $sub_data_dir/dev_2.tok.tc.bpe.$lang_1 | sed "s/^/<2$lang_2> /" >> $sub_data_dir/dev.src
	cat $sub_data_dir/dev_1.tok.tc.bpe.$lang_2 | sed "s/^/<2$lang_1> /" >> $sub_data_dir/dev.src
	cat $sub_data_dir/dev_2.tok.tc.bpe.$lang_2 $sub_data_dir/dev_1.tok.tc.bpe.$lang_1 > $sub_data_dir/dev.tgt
fi;
