#!/usr/bin/env python

# Copyright 2011-2013 Pierre de Buyl
#
# This file is part of f90h5md
#
# f90h5md is free software and is licensed under the modified BSD license (see
# LICENSE file).

types = dict()
types['i'] = 'integer'
types['d'] = 'double precision'
H5T = dict()
H5T['i'] = 'H5T_NATIVE_INTEGER'
H5T['d'] = 'H5T_NATIVE_DOUBLE'
dims = dict()
dims['s'] = ''
dims['1'] = '(:)'
dims['2'] = '(:,:)'
dims['3'] = '(:,:,:)'
dims['4'] = '(:,:,:,:)'

for t_k,t_v in types.iteritems():
    for d_k,d_v in dims.iteritems():
        if (d_k == 's'):
            rank = 1
        else:
            rank = int(d_k)+1
        s=''
        s+="""  !> Takes a single value and appends it to the appropriate dataset.
  !! @param ID h5md_t variable.
  !! @param data value of the observable.
  !! @param present_step integer time step.
  !! @param time real-valued time.
  !! @private"""
        s+="""
  subroutine h5md_write_obs_%s%s(ID, data, present_step, time)
    type(h5md_t), intent(inout) :: ID
    %s, intent(in) :: data%s
    integer, intent(in) :: present_step
    double precision, intent(in) :: time

    integer(HID_T) :: obs_s, mem_s
    integer(HSIZE_T) :: dims(%i), max_dims(%i), start(%i), num(%i)

""" % (t_k,d_k,t_v,d_v,rank,rank,rank,rank)
        if (d_k!='s'):
            s+="""
    dims(1:%i) = shape(data)
""" % (rank-1,)
        else:
            s+="""
    dims(1) = 1
"""

        s+="""
    call h5screate_simple_f(%i, dims, mem_s, h5_error)

    call h5dget_space_f(ID%% d_id , obs_s, h5_error)
    call h5sget_simple_extent_dims_f(obs_s, dims, max_dims, h5_error)
    call h5sclose_f(obs_s, h5_error)
""" % (rank-1, )
        if (d_k!='s'):
            s+="""
    start(1:%i) = 0
    num(1:%i) = dims(1:%i)
""" % (rank-1, rank-1, rank-1)
        s+="""    start(%i) = dims(%i)
    num(%i) = 1
    dims(%i) = dims(%i) + 1
    call h5dset_extent_f(ID%% d_id, dims, h5_error)
    call h5dget_space_f(ID%% d_id , obs_s, h5_error)
    call h5sselect_hyperslab_f(obs_s, H5S_SELECT_SET_F, start, num, h5_error)
    call h5dwrite_f(ID%% d_id, %s, data, num, h5_error, mem_space_id=mem_s, file_space_id=obs_s)
    call h5sclose_f(obs_s, h5_error)
    call h5sclose_f(mem_s, h5_error)

    call h5md_append_step_time(ID%% s_id, ID%% t_id, present_step, time)
       
  end subroutine h5md_write_obs_%s%s
""" % (rank,rank,rank,rank,rank,H5T[t_k],t_k,d_k)
        print s

