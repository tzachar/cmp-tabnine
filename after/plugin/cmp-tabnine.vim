if exists('g:loaded_cmp_tabnine')
  finish
endif
let g:loaded_cmp_tabnine = v:true

lua require'cmp'.register_source('tabnine', require'cmp_tabnine'.new())

