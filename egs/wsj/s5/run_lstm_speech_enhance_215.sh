#!/bin/bash

# this is a basic lstm script
# LSTM script runs for more epochs than the TDNN script
# and each epoch takes twice the time

# At this script level we don't support not running on GPU, as it would be painfully slow.
# If you want to run without GPU you'd have to call lstm/train.sh with --gpu false

stage=0
train_stage=0 #-10
affix=
common_egs_dir=

# LSTM options
splice_indexes="-2,-1,0,1,2"  # default -2,-1,0,1,2 0 0
lstm_delay=" -1 "  # default -1 -2 -3
label_delay=5
num_lstm_layers=1  # default 3
cell_dim=1024
hidden_dim=1024
recurrent_projection_dim=256
non_recurrent_projection_dim=256
chunk_width=20
chunk_left_context=40
chunk_right_context=0


# training options
num_epochs=10
initial_effective_lrate=0.0006
final_effective_lrate=0.00006
num_jobs_initial=8
num_jobs_final=8
momentum=0.5
num_chunk_per_minibatch=100
samples_per_iter=20000
remove_egs=false

#decode options
extra_left_context=
extra_right_context=
frames_per_chunk=

#End configuration section

echo "$0 $@" # Print the command line for logging

. cmd.sh
. ./path.sh
. ./utils/parse_options.sh


if ! cuda-compiled; then
  cat <<EOF && exit 1
This script is intended to be used with GPUs but you have not compiled Kaldi with CUDA
If you want to use GPUs (and have them), go to src/, and configure and make on a machine
where "nvcc" is installed.
EOF
fi

export cuda_cmd=run.pl

common_egs_dir=exp/nnet3/lstm_speech_a/egs
dir=exp/nnet3/lstm_joint_i_enhance_8_8

if [ $stage -le 8 ]; then
  steps/nnet3/lstm/train_rand_refine_215.sh --stage $train_stage \
    --label-delay $label_delay \
    --lstm-delay "$lstm_delay" \
    --num-epochs $num_epochs --num-jobs-initial $num_jobs_initial --num-jobs-final $num_jobs_final \
    --num-chunk-per-minibatch $num_chunk_per_minibatch \
    --samples-per-iter $samples_per_iter \
    --splice-indexes "$splice_indexes" \
    --feat-type raw \
    --cmvn-opts "--norm-means=false --norm-vars=false" \
    --initial-effective-lrate $initial_effective_lrate --final-effective-lrate $final_effective_lrate \
    --momentum $momentum \
    --cmd "$cuda_cmd" \
    --num-lstm-layers $num_lstm_layers \
    --cell-dim $cell_dim \
    --hidden-dim $hidden_dim \
    --recurrent-projection-dim $recurrent_projection_dim \
    --non-recurrent-projection-dim $non_recurrent_projection_dim \
    --chunk-width $chunk_width \
    --chunk-left-context $chunk_left_context \
    --chunk-right-context $chunk_right_context \
    --egs-dir "$common_egs_dir" \
    --remove-egs $remove_egs \
    --max-gpu-num 3 \
    data_fbank/train data_fbank/lang exp/tri4_ali $dir  || exit 1;
fi

if [ $stage -le 9 ]; then
  if [ -z $extra_left_context ]; then
    extra_left_context=$chunk_left_context
  fi
  if [ -z $extra_right_context ]; then
    extra_right_context=$chunk_right_context
  fi
  if [ -z $frames_per_chunk ]; then
    frames_per_chunk=$chunk_width
  fi
  for lm_suffix in  sw1_tg; do
    graph_dir=exp/tri4/graph_${lm_suffix}
    # use already-built graphs
    #for year in test; do
      #(
      #num_jobs=`cat data/test_${year}_hires/utt2spk|cut -d' ' -f2|sort -u|wc -l`
      num_jobs=24
      steps/nnet3/lstm/decode.sh --nj $num_jobs --cmd "$decode_cmd" \
	  --extra-left-context $extra_left_context \
	  --extra-right-context $extra_right_context \
	  --frames-per-chunk "$frames_per_chunk" --stage -2 \
	 $graph_dir data_fbank/eval2000 $dir/decode_eval2000_${lm_suffix} || exit 1;
      #) &
    #done
  done

  steps/lmrescore_const_arpa.sh --cmd "$decode_cmd" \
    data_fbank/lang_sw1_{tg,fsh_fg} data_fbank/eval2000 \
    $dir/decode_eval2000_sw1_{tg,fsh_fg}

fi

exit 0;

