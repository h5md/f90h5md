module h5md
  use hdf5
  implicit none

  integer :: h5_error

  type h5md_obs
     integer(HID_T) :: id
     double precision, allocatable :: d_buffer(:)
     integer, allocatable :: i_buffer(:)
     integer :: buffer_len
     integer :: buffer_i
  end type h5md_obs

  type h5md_t
     integer(HID_T) :: d_id
     integer(HID_T) :: s_id
     integer(HID_T) :: t_id
  end type h5md_t
  
contains

  ! opens a h5md file
  ! creates the '/h5md' group and gives it the attributes 'creator' and 
  ! 'version'. currently, only supports creating a new file.
  ! also creates 'trajectory' and 'observables' groups.
  ! file_id is the returned hdf5 location of the file
  ! filename is the name of the file
  ! prog_name is the name that appears in the 'creator' global attribute
  subroutine h5md_open_file(file_id, filename, prog_name)
    integer(HID_T), intent(out) :: file_id
    character(len=*), intent(in) :: filename, prog_name

    character(len=5) :: h5md_version
    integer(HID_T) :: h5_g_id, g_id
    integer(HID_T) :: a_type, a_space, a_id
    integer(HSIZE_T) :: a_size(1)

    call h5fcreate_f(filename, H5F_ACC_TRUNC_F, file_id, h5_error)

    call h5gcreate_f(file_id, 'h5md', h5_g_id, h5_error)

    call h5screate_f(H5S_SCALAR_F, a_space, h5_error)
    a_size(1) = len(prog_name)
    call h5tcopy_f(H5T_NATIVE_CHARACTER, a_type, h5_error)
    call h5tset_size_f(a_type, a_size(1), h5_error)
    
    call h5acreate_f(h5_g_id, 'creator', a_type, a_space, a_id, h5_error)
    call h5awrite_f(a_id, a_type, prog_name, a_size, h5_error)

    call h5aclose_f(a_id, h5_error)
    call h5sclose_f(a_space, h5_error)
    call h5tclose_f(a_type, h5_error)
    
    h5md_version = '0.1.0'
    a_size(1) = len(h5md_version)

    call h5screate_f(H5S_SCALAR_F, a_space, h5_error)
    call h5tcopy_f(H5T_NATIVE_CHARACTER, a_type, h5_error)
    call h5tset_size_f(a_type, a_size(1), h5_error)
    
    call h5acreate_f(h5_g_id, 'version', a_type, a_space, a_id, h5_error)
    call h5awrite_f(a_id, a_type, h5md_version, a_size, h5_error)

    call h5aclose_f(a_id, h5_error)
    call h5sclose_f(a_space, h5_error)
    call h5tclose_f(a_type, h5_error)

    call h5gclose_f(h5_g_id, h5_error)

    call h5gcreate_f(file_id, 'trajectory', g_id, h5_error)
    call h5gclose_f(g_id, h5_error)

    call h5gcreate_f(file_id, 'observables', g_id, h5_error)
    call h5gclose_f(g_id, h5_error)

  end subroutine h5md_open_file

  ! adds a trajectory group in a h5md file
  ! group_name is the name of a subgroup of 'trajectory'.
  subroutine h5md_create_trajectory_group(file_id, group_name)
    integer(HID_T), intent(inout) :: file_id
    character(len=*), intent(in) :: group_name

    integer(HID_T) :: traj_g_id
    
    call h5gcreate_f(file_id, 'trajectory/'//group_name , traj_g_id, h5_error)

    call h5gclose_f(traj_g_id, h5_error)

  end subroutine h5md_create_trajectory_group

  ! creates the step and time datasets in the specified group
  subroutine h5md_create_step_time(group_id)
    integer(HID_T), intent(inout) :: group_id

    integer :: rank
    integer(HSIZE_T) :: dims(1), max_dims(1), chunk_dims(1)
    integer(HID_T) :: s_id, d_id, plist

    rank = 1
    dims = (/ 0 /)
    max_dims = (/ H5S_UNLIMITED_F /)
    call h5screate_simple_f(rank, dims, s_id, h5_error, max_dims)
    chunk_dims = (/ 1024 /)
    call h5pcreate_f(H5P_DATASET_CREATE_F, plist, h5_error)
    call h5pset_chunk_f(plist, rank, chunk_dims, h5_error)
    call h5dcreate_f(group_id, 'step', H5T_NATIVE_INTEGER, s_id, d_id, h5_error, plist)
    call h5pclose_f(plist, h5_error)
    call h5dclose_f(d_id, h5_error)
    call h5sclose_f(s_id, h5_error)
    
    rank = 1
    dims = (/ 0 /)
    max_dims = (/ H5S_UNLIMITED_F /)
    call h5screate_simple_f(rank, dims, s_id, h5_error, max_dims)
    chunk_dims = (/ 1024 /)
    call h5pcreate_f(H5P_DATASET_CREATE_F, plist, h5_error)
    call h5pset_chunk_f(plist, rank, chunk_dims, h5_error)
    call h5dcreate_f(group_id, 'time', H5T_NATIVE_DOUBLE, s_id, d_id, h5_error, plist)
    call h5pclose_f(plist, h5_error)
    call h5dclose_f(d_id, h5_error)
    call h5sclose_f(s_id, h5_error)
    
  end subroutine h5md_create_step_time

  ! add a trajectory dataset to a trajectory group of name trajectory_name
  ! group_name is an optional group name for the trajectory group
  ! trajectory_name can be 'position', 'velocity', 'force' or 'species'
  ! N is the number of atoms, D the spatial dimension
  ! species_react is an optional argument. if set to .true., 'species' will be
  ! time dependent, if set to .false., 'species' will not possess the time
  ! dimension
  ! link_from is the name of another trajectory from which the time can be copied
  subroutine h5md_add_trajectory_data(file_id, trajectory_name, N, D, ID, group_name, species_react, link_from)
    integer(HID_T), intent(in) :: file_id
    character(len=*), intent(in) :: trajectory_name
    integer, intent(in) :: N, D
    type(h5md_t), intent(out) :: ID
    character(len=*), intent(in), optional :: group_name
    logical, intent(in), optional :: species_react
    character(len=*), intent(in), optional :: link_from
    
    character(len=128) :: path
    integer :: rank
    integer(HSIZE_T) :: dims(3), max_dims(3), chunk_dims(3)
    integer(HID_T) :: traj_g_id, g_id, s_id, plist

    if ( (trajectory_name .ne. 'position') .and. (trajectory_name .ne. 'velocity') .and. (trajectory_name .ne. 'force') .and. (trajectory_name .ne. 'species') ) then
       write(*,*) 'non conforming trajectory name in h5md_add_trajectory_data'
       stop
    end if

    if (present(group_name)) then
       call h5gopen_f(file_id, 'trajectory/'//group_name, traj_g_id, h5_error)
    else
       call h5gopen_f(file_id, 'trajectory', traj_g_id, h5_error)
    end if
    path = trajectory_name

    ! g_id is opened as the container of trajectory_name
    call h5gcreate_f(traj_g_id, path, g_id, h5_error)
       
    if (trajectory_name .eq. 'species') then
       if (present(species_react) .and. (species_react) ) then
          rank = 2
          dims = (/ N, 0, 0 /)
          max_dims = (/ N, H5S_UNLIMITED_F, 0 /)
          chunk_dims = (/ N, 1, 0 /)
       else
          rank = 1
          dims = (/ N, 0, 0 /)
          max_dims = (/ N, 0, 0 /)
          chunk_dims = (/ N, 0, 0 /)
       end if
    else
       rank = 3
       dims = (/ D, N, 0 /)
       max_dims = (/ D, N, H5S_UNLIMITED_F /)
       chunk_dims = (/ D, N, 1 /)
    end if

    call h5screate_simple_f(rank, dims, s_id, h5_error, max_dims)
    call h5pcreate_f(H5P_DATASET_CREATE_F, plist, h5_error)
    call h5pset_chunk_f(plist, rank, chunk_dims, h5_error)
    if (trajectory_name .ne. 'species') then
       call h5dcreate_f(g_id, 'coordinates', H5T_NATIVE_DOUBLE, s_id, ID% d_id, h5_error, plist)
    else
       call h5dcreate_f(g_id, 'coordinates', H5T_NATIVE_INTEGER, s_id, ID% d_id, h5_error, plist)
    end if
    call h5pclose_f(plist, h5_error)
    call h5sclose_f(s_id, h5_error)

    if (present(link_from)) then
       call h5lcreate_hard_f(traj_g_id, link_from//'/step', g_id, 'step', h5_error)
       call h5lcreate_hard_f(traj_g_id, link_from//'/time', g_id, 'time', h5_error)
    else
       call h5md_create_step_time(g_id)
    end if

    call h5dopen_f(g_id, 'step', ID% s_id, h5_error)
    call h5dopen_f(g_id, 'time', ID% t_id, h5_error)

    call h5gclose_f(g_id, h5_error)
    call h5gclose_f(traj_g_id, h5_error)
    
  end subroutine h5md_add_trajectory_data

  ! beware: should be doubled for integer and real values, with explicit interfacing
  ! adds a "time frame" to a trajectory
  ! traj_id is the trajectory dataset
  ! data is the actual data of dim (D,N)
  ! step is the integer step of simulation. if the linked 'step' dataset's latest value
  ! is present_step, 'step' and 'time' are not updated. Else, they are.
  subroutine h5md_write_trajectory_data_d(ID, data, present_step, time)
    type(h5md_t), intent(inout) :: ID
    double precision, intent(in) :: data(:,:)
    integer, intent(in) :: present_step
    double precision, intent(in) :: time
    
    integer(HID_T) :: d_file_space, mem_s, step_id, step_s
    integer(HSIZE_T) :: dims(3), max_dims(3), start(3), num(3)
    integer :: last_step(1)
    double precision :: last_time(1)

    dims(1:2) = shape(data)
    call h5screate_simple_f(2, dims, mem_s, h5_error)

    call h5dget_space_f(ID% d_id, d_file_space, h5_error)
    call h5sget_simple_extent_dims_f(d_file_space, dims, max_dims, h5_error)
    dims(3) = dims(3) + 1
    call h5sclose_f(d_file_space, h5_error)
    call h5dset_extent_f(ID% d_id, dims, h5_error)
    call h5dget_space_f(ID% d_id, d_file_space, h5_error)

    start(1) = 0 ; start(2) = 0 ; start(3) = dims(3)-1
    num(1) = dims(1) ; num(2) = dims(2) ; num(3) = 1

    call h5sselect_hyperslab_f(d_file_space, H5S_SELECT_SET_F, start, num, h5_error)
    call h5dwrite_f(ID% d_id, H5T_NATIVE_DOUBLE, data, dims, h5_error, mem_space_id=mem_s, file_space_id=d_file_space)
    call h5sclose_f(d_file_space, h5_error)
    call h5sclose_f(mem_s, h5_error)

    call h5md_append_step_time(ID% s_id, ID% t_id, present_step, time)

  end subroutine h5md_write_trajectory_data_d

  ! beware: should be doubled for integer and real values, with explicit interfacing
  ! adds a "time frame" to a trajectory
  ! traj_id is the trajectory dataset
  ! data is the actual data of dim (D,N)
  ! step is the integer step of simulation. if the linked 'step' dataset's latest value
  ! is present_step, 'step' and 'time' are not updated. Else, they are.
  subroutine h5md_write_trajectory_data_d1d(ID, data, present_step, time)
    type(h5md_t), intent(inout) :: ID
    double precision, intent(in) :: data(:)
    integer, intent(in) :: present_step
    double precision, intent(in) :: time
    
    integer(HID_T) :: d_file_space, mem_s, step_id, step_s
    integer(HSIZE_T) :: dims(3), max_dims(3), start(3), num(3)
    integer :: last_step(1)
    double precision :: last_time(1)

    dims(1:1) = shape(data)
    call h5screate_simple_f(1, dims, mem_s, h5_error)

    call h5dget_space_f(ID% d_id, d_file_space, h5_error)
    call h5sget_simple_extent_dims_f(d_file_space, dims, max_dims, h5_error)
    dims(3) = dims(3) + 1
    call h5sclose_f(d_file_space, h5_error)
    call h5dset_extent_f(ID% d_id, dims, h5_error)
    call h5dget_space_f(ID% d_id, d_file_space, h5_error)

    start(1) = 0 ; start(2) = 0 ; start(3) = dims(3)-1
    num(1) = dims(1) ; num(2) = dims(2) ; num(3) = 1

    call h5sselect_hyperslab_f(d_file_space, H5S_SELECT_SET_F, start, num, h5_error)
    call h5dwrite_f(ID% d_id, H5T_NATIVE_DOUBLE, data, dims, h5_error, mem_space_id=mem_s, file_space_id=d_file_space)
    call h5sclose_f(d_file_space, h5_error)
    call h5sclose_f(mem_s, h5_error)

    call h5md_append_step_time(ID% s_id, ID% t_id, present_step, time)

  end subroutine h5md_write_trajectory_data_d1d

  subroutine h5md_append_step_time(s_id, t_id, step, time)
    integer(HID_T), intent(inout) :: s_id, t_id
    integer, intent(in) :: step
    double precision, intent(in) :: time

    integer(HID_T) :: file_s, mem_s
    integer(HSIZE_T) :: dims(1), max_dims(1), start(1), num(1)
    integer :: last_step(1)

    ! open step
    call h5dget_space_f(s_id, file_s, h5_error)
    call h5sget_simple_extent_dims_f(file_s, dims, max_dims, h5_error)

    if (dims(1) .le. 0) then
       last_step(1) = -1
    else
       start(1) = dims(1)-1
       num(1) = 1
       call h5screate_simple_f(1, num, mem_s, h5_error)
       call h5sselect_hyperslab_f(file_s, H5S_SELECT_SET_F, start, num, h5_error)
       call h5dread_f(s_id, H5T_NATIVE_INTEGER, last_step, num, h5_error, mem_space_id=mem_s, file_space_id=file_s)
       call h5sclose_f(mem_s, h5_error)
    end if

    ! check last
    if (last_step(1) .gt. step) then ! if last > present_step -> error
       write(*,*) 'error, last step is bigger than present step'
    else if (last_step(1) .lt. step) then ! else if last < present_step -> extend step and append present_step, same for time
       ! add step value to the end of the step dataset

       dims(1) = 1
       call h5screate_simple_f(1, dims, mem_s, h5_error)
       call h5sget_simple_extent_dims_f(file_s, dims, max_dims, h5_error)
       call h5sclose_f(file_s, h5_error)
       start(1) = dims(1)
       num(1) = 1
       dims(1) = dims(1) + 1
       call h5dset_extent_f(s_id, dims, h5_error)
       call h5dget_space_f(s_id, file_s, h5_error)

       call h5sselect_hyperslab_f(file_s, H5S_SELECT_SET_F, start, num, h5_error)
       call h5dwrite_f(s_id, H5T_NATIVE_INTEGER, step, num, h5_error, mem_space_id=mem_s, file_space_id=file_s)
       call h5sclose_f(file_s, h5_error)
       call h5sclose_f(mem_s, h5_error)

       ! add time value to the end of the time dataset
       dims(1) = 1
       call h5screate_simple_f(1, dims, mem_s, h5_error)

       call h5dget_space_f(t_id, file_s, h5_error)
       call h5sget_simple_extent_dims_f(file_s, dims, max_dims, h5_error)
       call h5sclose_f(file_s, h5_error)
       dims(1) = dims(1) + 1
       call h5dset_extent_f(t_id, dims, h5_error)
       call h5dget_space_f(t_id, file_s, h5_error)
       call h5sget_simple_extent_dims_f(file_s, dims, max_dims, h5_error)
       start(1) = dims(1) - 1
       num(1) = 1
       call h5sselect_hyperslab_f(file_s, H5S_SELECT_SET_F, start, num, h5_error)
       call h5dwrite_f(t_id, H5T_NATIVE_DOUBLE, time, num, h5_error, mem_space_id=mem_s, file_space_id=file_s)
       call h5sclose_f(file_s, h5_error)
       call h5sclose_f(mem_s, h5_error)

    end if ! else if last = present_step, do nothing

  end subroutine h5md_append_step_time

  subroutine h5md_create_obs(file_id, name, ID, link_from, is_int)
    integer(HID_T), intent(inout) :: file_id
    type(h5md_t), intent(out) :: ID
    character(len=*), intent(in) :: name
    character(len=*), intent(in), optional :: link_from
    logical, intent(in), optional :: is_int

    integer(HID_T) :: file_s, plist, g_id
    integer(HSIZE_T) :: dims(1), max_dims(1), chunk_dims(1)
    integer :: rank

    call h5gcreate_f(file_id, 'observables/'//name, g_id, h5_error)

    rank = 1
    dims = (/ 0 /)
    max_dims = (/ H5S_UNLIMITED_F /)
    call h5screate_simple_f(rank, dims, file_s, h5_error, max_dims)
    chunk_dims = (/ 128 /)
    call h5pcreate_f(H5P_DATASET_CREATE_F, plist, h5_error)
    call h5pset_chunk_f(plist, rank, chunk_dims, h5_error)
    if (present(is_int) .and. is_int) then
       call h5dcreate_f(g_id, 'samples', H5T_NATIVE_INTEGER, file_s, ID% d_id, h5_error, plist)
    else
       call h5dcreate_f(g_id, 'samples', H5T_NATIVE_DOUBLE, file_s, ID% d_id, h5_error, plist)
    end if
    call h5pclose_f(plist, h5_error)
    call h5sclose_f(file_s, h5_error)

    if (present(link_from)) then
       call h5lcreate_hard_f(file_id, 'observables/'//link_from//'/step', g_id, 'step', h5_error)
       call h5lcreate_hard_f(file_id, 'observables/'//link_from//'/time', g_id, 'time', h5_error)
    else
       call h5md_create_step_time(g_id)
    end if

    call h5dopen_f(g_id, 'step', ID% s_id, h5_error)
    call h5dopen_f(g_id, 'time', ID% t_id, h5_error)

    call h5gclose_f(g_id, h5_error)
    
  end subroutine h5md_create_obs

  ! takes a single value and appends it to the appropriate buffer.
  ! if the buffer size is reached, the buffer is dumped to the file.
  subroutine h5md_append_obs_value_d(ID, value, present_step, time)
    type(h5md_t), intent(inout) :: ID
    double precision, intent(in) :: value
    integer, intent(in) :: present_step
    double precision, intent(in) :: time

    integer(HID_T) :: obs_s, mem_s
    integer(HSIZE_T) :: dims(1), max_dims(1), start(1), num(1)
    
    dims(1) = 1
    call h5screate_simple_f(1, dims, mem_s, h5_error)

    call h5dget_space_f(ID% d_id , obs_s, h5_error)
    call h5sget_simple_extent_dims_f(obs_s, dims, max_dims, h5_error)
    call h5sclose_f(obs_s, h5_error)
    start = dims ; num(1) = 1
    dims(1) = dims(1) + 1
    call h5dset_extent_f(ID% d_id, dims, h5_error)
    call h5dget_space_f(ID% d_id , obs_s, h5_error)
    call h5sselect_hyperslab_f(obs_s, H5S_SELECT_SET_F, start, num, h5_error)
    call h5dwrite_f(ID% d_id, H5T_NATIVE_DOUBLE, value, num, h5_error, mem_space_id=mem_s, file_space_id=obs_s)
    call h5sclose_f(obs_s, h5_error)
    call h5sclose_f(mem_s, h5_error)

    call h5md_append_step_time(ID% s_id, ID% t_id, present_step, time)
       
  end subroutine h5md_append_obs_value_d

  subroutine h5md_close_obs(obs)
    type(h5md_obs), intent(inout) :: obs

    if (obs% buffer_i .gt. 0) then
       !call h5md_append_obs_value_d(obs, force_dump = .true.)
    end if

    call h5dclose_f(obs% id, h5_error)

  end subroutine h5md_close_obs
  
  subroutine h5md_close_ID(ID)
    type(h5md_t), intent(inout) :: ID

    call h5dclose_f(ID% d_id, h5_error)
    call h5dclose_f(ID% s_id, h5_error)
    call h5dclose_f(ID% t_id, h5_error)

  end subroutine h5md_close_ID

end module h5md
